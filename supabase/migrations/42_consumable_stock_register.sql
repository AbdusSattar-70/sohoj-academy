create table public.consumable_items(id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),name text not null,unit text not null check(unit in('PIECE','PACK','REAM','BOX','LITRE','KG')),reorder_level numeric(14,3) not null default 0 check(reorder_level>=0),is_active boolean not null default true,revision integer not null default 1,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now());
create unique index consumable_name on public.consumable_items(organization_id,lower(btrim(name)));
create table public.consumable_movements(id uuid primary key default gen_random_uuid(),item_id uuid not null references public.consumable_items(id),event_order bigint generated always as identity unique,kind text not null check(kind in('RECEIPT','ISSUE','COUNT')),quantity numeric(14,3) not null,physical_quantity numeric(14,3),reference text not null,purchase_id uuid references public.finance_purchases(id),actor_id uuid not null references public.profiles(id),reason text not null,created_at timestamptz not null default now());
create index consumable_movement_order on public.consumable_movements(item_id,event_order desc);
alter table public.consumable_items enable row level security;alter table public.consumable_movements enable row level security;revoke all on public.consumable_items,public.consumable_movements from public,anon,authenticated;
create trigger consumable_no_delete before delete on public.consumable_items for each row execute function public.prevent_permanent_record_delete();
create trigger consumable_history before update or delete on public.consumable_movements for each row execute function public.prevent_permanent_record_delete();
create function public.consumable_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;org uuid;item public.consumable_items;quantity_value numeric:=(p_input->>'quantity')::numeric;balance_value numeric;latest bigint;ref text:=btrim(p_input->>'reference');why text:=btrim(p_input->>'reason');reorder numeric:=(p_input->>'reorder_level')::numeric;purchase uuid:=nullif(p_input->>'purchase_id','')::uuid;rid uuid;res jsonb;
begin
 if actor is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Consumable management permission required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 1000 then raise exception 'Request identity and explanation required.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if p_input->>'action'='SAVE' then
  if coalesce(length(btrim(p_input->>'name')),0) not between 2 and 150 or reorder is null or reorder::text in('NaN','Infinity','-Infinity') or reorder<0 or reorder>99999999 or round(reorder,3)<>reorder or p_input->>'unit' not in('PIECE','PACK','REAM','BOX','LITRE','KG') then raise exception 'Choose a name, unit and finite reorder quantity (three decimals maximum).';end if;
  if nullif(p_input->>'id','') is null then insert into public.consumable_items(organization_id,name,unit,reorder_level,created_by) values(org,btrim(p_input->>'name'),p_input->>'unit',reorder,actor) returning * into item;
  else
   select * into item from public.consumable_items where id=(p_input->>'id')::uuid and organization_id=org for update;
   if item.id is null or item.revision is distinct from (p_input->>'revision')::integer then raise exception 'Item changed. Review current details.';end if;
   if item.unit<>p_input->>'unit' and exists(select 1 from public.consumable_movements where item_id=item.id) then raise exception 'Unit cannot change after stock history. Create a separate item.';end if;
   update public.consumable_items set name=btrim(p_input->>'name'),unit=p_input->>'unit',reorder_level=reorder,is_active=(p_input->>'is_active')::boolean,revision=revision+1 where id=item.id returning * into item;
  end if;rid:=item.id;
 elsif p_input->>'action' in('RECEIPT','ISSUE','COUNT') then
  select * into item from public.consumable_items where id=(p_input->>'id')::uuid and organization_id=org for update;
  if item.id is null or not item.is_active then raise exception 'Choose an active consumable item.';end if;
  select coalesce(sum(quantity),0),coalesce(max(event_order),0) into balance_value,latest from public.consumable_movements where item_id=item.id;
  if latest is distinct from (p_input->>'expected_order')::bigint then raise exception 'Stock changed. Review current quantity before posting.';end if;
  if quantity_value is null or quantity_value::text in('NaN','Infinity','-Infinity') or quantity_value<0 or quantity_value>99999999 or round(quantity_value,3)<>quantity_value or coalesce(length(ref),0) not between 2 and 200 or coalesce((p_input->>'confirmed')::boolean,false) is not true then raise exception 'Confirm actual movement/count, finite quantity and document reference.';end if;
  if p_input->>'action'<>'COUNT' and quantity_value=0 then raise exception 'Movement quantity must be positive.';end if;
  if p_input->>'action'='ISSUE' and quantity_value>balance_value then raise exception 'Issue exceeds available stock.';end if;
  if purchase is not null and (p_input->>'action'<>'RECEIPT' or not exists(select 1 from public.finance_purchases where id=purchase and organization_id=org and status='POSTED')) then raise exception 'Receipt may link only a posted academy purchase.';end if;
  insert into public.consumable_movements(item_id,kind,quantity,physical_quantity,reference,purchase_id,actor_id,reason) values(item.id,p_input->>'action',case p_input->>'action' when 'ISSUE' then -quantity_value when 'COUNT' then quantity_value-balance_value else quantity_value end,case when p_input->>'action'='COUNT' then quantity_value end,ref,purchase,actor,why) returning id into rid;
 else raise exception 'Unknown consumable action.';end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'CONSUMABLE',item.id::text,p_input->>'action',why,jsonb_build_object('record_id',rid,'quantity',quantity_value),req);res:=jsonb_build_object('id',rid,'message','Consumable record saved. No accounting journal was created.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,res);return res;
end $$;
revoke all on function public.consumable_command(jsonb) from public,anon;grant execute on function public.consumable_command(jsonb) to authenticated;
create function public.consumable_workspace(p_page integer default 1,p_search text default '') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;rows jsonb;total integer;
begin
 if auth.uid() is null or not public.has_permission('accounting.view') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Accounting access required.';end if;
 if p_page not between 1 and 10000 or length(coalesce(p_search,''))>100 then raise exception 'Invalid stock page/search.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select count(*) into total from public.consumable_items where organization_id=org and (coalesce(p_search,'')='' or name ilike '%'||p_search||'%');
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select i.*,coalesce((select sum(quantity) from public.consumable_movements where item_id=i.id),0) stock,coalesce((select max(event_order) from public.consumable_movements where item_id=i.id),0) expected_order,(select coalesce(jsonb_agg(to_jsonb(h)),'[]'::jsonb) from(select m.id,m.kind,m.quantity,m.physical_quantity,m.reference,m.created_at,m.reason,p.display_name actor from public.consumable_movements m join public.profiles p on p.id=m.actor_id where item_id=i.id order by event_order desc limit 10)h) history from public.consumable_items i where organization_id=org and (coalesce(p_search,'')='' or name ilike '%'||p_search||'%') order by i.is_active desc,i.name,i.id limit 25 offset (p_page-1)*25)x;
 return jsonb_build_object('total',total,'rows',rows,'canManage',public.has_permission('accounting.expense.manage'));
end $$;
revoke all on function public.consumable_workspace(integer,text) from public,anon;grant execute on function public.consumable_workspace(integer,text) to authenticated;

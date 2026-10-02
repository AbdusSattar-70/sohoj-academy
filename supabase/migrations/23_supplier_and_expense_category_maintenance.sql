create function public.purchase_directory_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;org uuid;kind text:=p_input->>'kind';record_id uuid:=nullif(p_input->>'id','')::uuid;active boolean:=(p_input->>'is_active')::boolean;name_value text:=btrim(p_input->>'name');reason text:=btrim(p_input->>'reason');before_value jsonb;after_value jsonb;v public.vendors;c public.finance_expense_categories;result jsonb;
begin
 if actor is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if req is null or active is null or coalesce(length(reason),0)<5 or coalesce(length(name_value),0) not between 2 and 200 then raise exception 'Enter a name, active status and clear reason.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;if org is null then raise exception 'Active academy unavailable.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if kind='VENDOR' then
  if record_id is not null then
   select * into v from public.vendors where id=record_id and organization_id=org for update;if v.id is null then raise exception 'Supplier unavailable.';end if;
   if v.updated_at is distinct from (p_input->>'expected_updated_at')::timestamptz then raise exception 'Supplier changed. Refresh before editing.';end if;before_value:=to_jsonb(v);
  end if;
  perform pg_advisory_xact_lock(hashtextextended(org::text||lower(name_value),22));
  if active and exists(select 1 from public.vendors where organization_id=org and is_active and lower(btrim(name))=lower(name_value) and id is distinct from record_id) then raise exception 'An active supplier with this name already exists.';end if;
  if nullif(btrim(p_input->>'email'),'') is not null and p_input->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter a valid supplier email or leave it empty.';end if;
  if record_id is null then
   insert into public.vendors(organization_id,name,mobile,email,address,service_category,is_active,created_by) values(org,name_value,nullif(btrim(p_input->>'mobile'),''),nullif(lower(btrim(p_input->>'email')),''),nullif(btrim(p_input->>'address'),''),nullif(btrim(p_input->>'service_category'),''),active,actor) returning * into v;
  else
   update public.vendors set name=name_value,mobile=nullif(btrim(p_input->>'mobile'),''),email=nullif(lower(btrim(p_input->>'email')),''),address=nullif(btrim(p_input->>'address'),''),service_category=nullif(btrim(p_input->>'service_category'),''),is_active=active,updated_at=clock_timestamp() where id=record_id returning * into v;
  end if;record_id:=v.id;after_value:=to_jsonb(v);
 elsif kind='CATEGORY' then
  if record_id is not null then
   select * into c from public.finance_expense_categories where id=record_id and organization_id=org for update;if c.id is null then raise exception 'Category unavailable.';end if;
   if md5(to_jsonb(c)::text) is distinct from p_input->>'token' then raise exception 'Category changed. Refresh before editing.';end if;before_value:=to_jsonb(c);
   if c.code is distinct from p_input->>'code' then raise exception 'Category code is permanent. Edit its name or active status instead.';end if;
  end if;
  if p_input->>'code' is null or p_input->>'code' !~ '^[A-Z][A-Z0-9_]{1,49}$' then raise exception 'Use a category code of 2–50 uppercase letters, digits or underscores.';end if;
  perform pg_advisory_xact_lock(hashtextextended(org::text||(p_input->>'code'),24));
  if exists(select 1 from public.finance_expense_categories where organization_id=org and code=p_input->>'code' and id is distinct from record_id) then raise exception 'This category code already exists, including inactive history.';end if;
  if not exists(select 1 from public.finance_accounts where id=(p_input->>'expense_account_id')::uuid and organization_id=org and account_type='EXPENSE' and (not active or is_active)) then raise exception 'Select an expense ledger account; active categories require an active account.';end if;
  if record_id is null then
   insert into public.finance_expense_categories(organization_id,code,name,expense_account_id,is_active,created_by) values(org,p_input->>'code',name_value,(p_input->>'expense_account_id')::uuid,active,actor) returning * into c;
  else update public.finance_expense_categories set name=name_value,expense_account_id=(p_input->>'expense_account_id')::uuid,is_active=active where id=record_id returning * into c;end if;
  record_id:=c.id;after_value:=to_jsonb(c);
 else raise exception 'Choose supplier or expense category.';end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data) values(req,actor,kind,record_id::text,case when before_value is null then 'CREATE' when not active then 'MARK_INACTIVE' else 'EDIT' end,reason,before_value,after_value);
 result:=jsonb_build_object('id',record_id,'message','Saved. Historical expenses remain unchanged; inactive records cannot be selected for new purchases.');
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.purchase_directory_command(jsonb) from public,anon;
grant execute on function public.purchase_directory_command(jsonb) to authenticated;

create function public.purchase_directory_workspace(p_kind text default 'VENDOR',p_page integer default 1,p_search text default '') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;rows jsonb;total integer;
begin
 if auth.uid() is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if p_kind not in('VENDOR','CATEGORY') or p_page is null or p_page not between 1 and 100000 or p_search is null or length(p_search)>100 then raise exception 'Invalid directory filter.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 if p_kind='VENDOR' then
  select count(*) into total from public.vendors where organization_id=org and (p_search='' or concat_ws(' ',name,mobile,email,vendor_no) ilike '%'||p_search||'%');
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select id,vendor_no code,name,mobile,email,address,service_category,is_active,updated_at::text token,null::uuid expense_account_id from public.vendors where organization_id=org and (p_search='' or concat_ws(' ',name,mobile,email,vendor_no) ilike '%'||p_search||'%') order by name,id limit 25 offset (p_page-1)*25)x;
 else
  select count(*) into total from public.finance_expense_categories where organization_id=org and (p_search='' or concat_ws(' ',name,code) ilike '%'||p_search||'%');
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select id,code,name,null::text mobile,null::text email,null::text address,null::text service_category,is_active,md5(to_jsonb(c)::text) token,expense_account_id from public.finance_expense_categories c where organization_id=org and (p_search='' or concat_ws(' ',name,code) ilike '%'||p_search||'%') order by name,id limit 25 offset (p_page-1)*25)x;
 end if;
 return jsonb_build_object('kind',p_kind,'page',p_page,'total',total,'rows',rows,'accounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'active',is_active) order by code) from public.finance_accounts where organization_id=org and account_type='EXPENSE'),'[]'::jsonb));
end $$;
revoke all on function public.purchase_directory_workspace(text,integer,text) from public,anon;
grant execute on function public.purchase_directory_workspace(text,integer,text) to authenticated;

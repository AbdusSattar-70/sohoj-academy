-- Expose read-only account balances without granting clients the internal
-- posting/settlement helper directly.
create or replace function public.finance_read_account_balance(
  p_account_id uuid,
  p_as_of date default current_date
)
returns numeric
language plpgsql stable security definer set search_path=public as $$
begin
  if auth.uid() is null or not public.has_permission('accounting.view') then
    raise exception 'Accounting view permission required.';
  end if;
  if p_account_id is null or p_as_of is null or not exists(
    select 1 from public.finance_accounts where id=p_account_id and is_active
  ) then raise exception 'Choose an active financial account and date.'; end if;
  return coalesce(public.finance_account_balance(p_account_id,p_as_of),0);
end $$;
revoke all on function public.finance_read_account_balance(uuid,date) from public,anon;
grant execute on function public.finance_read_account_balance(uuid,date) to authenticated;

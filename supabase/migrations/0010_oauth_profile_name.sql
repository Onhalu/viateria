-- Google and Apple put the person's name in raw_user_meta_data as
-- full_name or name. Email sign-up still sends display_name.
-- Display only: this trigger inserts the profile row. Authorization
-- stays on auth.uid() in the existing RLS policies.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, locale)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), '')
    ),
    coalesce(nullif(new.raw_user_meta_data ->> 'locale', ''), 'cs')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

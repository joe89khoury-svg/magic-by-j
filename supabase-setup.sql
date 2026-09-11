-- =====================================================================
--  Magic by J, backend setup
--  Paste this whole file into the Supabase SQL Editor and press Run.
--  Safe to run more than once.
-- =====================================================================

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------
-- 1. Private settings. Never readable by the public.
-- ---------------------------------------------------------------------
create table if not exists app_config (
  key   text primary key,
  value text not null
);
alter table app_config enable row level security;
-- deliberately no policies, so nobody can read this from the website

-- ---------------------------------------------------------------------
-- 2. The promotion counter. One single row.
-- ---------------------------------------------------------------------
create table if not exists promo (
  id        int primary key default 1,
  total     int not null default 20,
  remaining int not null default 20,
  active    boolean not null default true,
  constraint promo_one_row check (id = 1)
);

insert into promo (id, total, remaining, active)
values (1, 20, 20, true)
on conflict (id) do nothing;

alter table promo enable row level security;

drop policy if exists "anyone can read the counter" on promo;
create policy "anyone can read the counter"
  on promo for select using (true);
-- no insert or update policy, so the counter can only move through place_order

-- ---------------------------------------------------------------------
-- 3. Orders
-- ---------------------------------------------------------------------
create table if not exists orders (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  first_name text not null,
  last_name  text not null,
  email      text not null,
  phone      text not null,
  address    text not null,
  city       text not null,
  quantity   int  not null,
  unit_price numeric,
  currency   text
);
alter table orders enable row level security;
-- no public policies, orders are written only by the function below

-- ---------------------------------------------------------------------
-- 4. WhatsApp alert, fired on every new order
-- ---------------------------------------------------------------------
create or replace function notify_whatsapp()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_phone text;
  v_key   text;
  v_rem   int;
  v_msg   text;
begin
  select value into v_phone from app_config where key = 'whatsapp_phone';
  select value into v_key   from app_config where key = 'callmebot_apikey';

  -- not configured yet, skip quietly
  if v_phone is null or v_key is null then
    return new;
  end if;

  select remaining into v_rem from promo where id = 1;

  v_msg :=
    'New Magic by J order'                                  || chr(10) ||
    new.first_name || ' ' || new.last_name                  || chr(10) ||
    'Quantity: '   || new.quantity                          || chr(10) ||
    'Phone: '      || new.phone                             || chr(10) ||
    'Email: '      || new.email                             || chr(10) ||
    'City: '       || new.city                              || chr(10) ||
    'Address: '    || new.address                           || chr(10) ||
    'Left in offer: ' || coalesce(v_rem::text, 'not tracked');

  perform net.http_get(
    url    := 'https://api.callmebot.com/whatsapp.php',
    params := jsonb_build_object('phone', v_phone, 'apikey', v_key, 'text', v_msg)
  );

  return new;
exception when others then
  -- never let a failed notification block a real order
  return new;
end;
$$;

drop trigger if exists orders_notify_whatsapp on orders;
create trigger orders_notify_whatsapp
  after insert on orders
  for each row execute function notify_whatsapp();

-- ---------------------------------------------------------------------
-- 5. Placing an order. Decrements the counter safely, even if two
--    people order at the exact same moment.
-- ---------------------------------------------------------------------
create or replace function place_order(
  p_first_name text,
  p_last_name  text,
  p_email      text,
  p_phone      text,
  p_address    text,
  p_city       text,
  p_quantity   int,
  p_unit_price numeric default null,
  p_currency   text    default '$'
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_total     int;
  v_remaining int;
  v_active    boolean;
  v_order_id  bigint;
begin
  if coalesce(trim(p_first_name), '') = ''
     or coalesce(trim(p_last_name), '') = ''
     or coalesce(trim(p_email), '') = ''
     or coalesce(trim(p_phone), '') = ''
     or coalesce(trim(p_address), '') = ''
     or coalesce(trim(p_city), '') = '' then
    raise exception 'Please fill in all fields.';
  end if;

  if p_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Please enter a valid email address.';
  end if;

  if p_quantity is null or p_quantity < 1 or p_quantity > 10 then
    raise exception 'Invalid quantity.';
  end if;

  -- lock the single counter row so simultaneous orders queue up
  select total, remaining, active
    into v_total, v_remaining, v_active
    from promo where id = 1
    for update;

  if v_active and v_remaining < p_quantity then
    return json_build_object(
      'ok', false, 'reason', 'sold_out',
      'remaining', v_remaining, 'total', v_total
    );
  end if;

  -- decrement first, so the WhatsApp alert reports the correct number left
  if v_active then
    update promo
       set remaining = remaining - p_quantity
     where id = 1
    returning remaining into v_remaining;
  end if;

  insert into orders (first_name, last_name, email, phone, address, city,
                      quantity, unit_price, currency)
  values (trim(p_first_name), trim(p_last_name), trim(p_email), trim(p_phone),
          trim(p_address), trim(p_city), p_quantity, p_unit_price, p_currency)
  returning id into v_order_id;

  return json_build_object(
    'ok', true, 'order_id', v_order_id,
    'remaining', v_remaining, 'total', v_total
  );
end;
$$;

revoke all on function place_order(text,text,text,text,text,text,int,numeric,text) from public;
grant execute on function place_order(text,text,text,text,text,text,int,numeric,text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Updating the promotion from the backoffice, protected by a passphrase
-- ---------------------------------------------------------------------
create or replace function set_promo(
  p_secret    text,
  p_total     int,
  p_remaining int,
  p_active    boolean
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare v_secret text;
begin
  select value into v_secret from app_config where key = 'admin_secret';

  if v_secret is null or p_secret is null or p_secret <> v_secret then
    perform pg_sleep(1);          -- slow down guessing
    raise exception 'Not authorised.';
  end if;

  if p_total < 0 or p_remaining < 0 or p_remaining > p_total then
    raise exception 'Remaining must be between 0 and the batch total.';
  end if;

  update promo
     set total = p_total, remaining = p_remaining, active = p_active
   where id = 1;

  return json_build_object('ok', true, 'total', p_total,
                           'remaining', p_remaining, 'active', p_active);
end;
$$;

revoke all on function set_promo(text,int,int,boolean) from public;
grant execute on function set_promo(text,int,int,boolean) to anon, authenticated;


-- =====================================================================
--  NOW FILL IN YOUR OWN DETAILS
--  Edit the three values below, then run just this block again.
-- =====================================================================

insert into app_config (key, value) values
  ('whatsapp_phone',   '+9613803480'),        -- where alerts are sent
  ('callmebot_apikey', 'PUT_YOUR_KEY_HERE'),  -- from the CallMeBot setup
  ('admin_secret',     'change-this-passphrase')
on conflict (key) do update set value = excluded.value;

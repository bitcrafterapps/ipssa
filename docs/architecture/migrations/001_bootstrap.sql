-- 001_bootstrap.sql
-- Base extensions, service schemas, and shared helpers.

create extension if not exists pgcrypto;
create extension if not exists citext;
create extension if not exists pg_trgm;

create schema if not exists auth;
create schema if not exists core;
create schema if not exists media;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

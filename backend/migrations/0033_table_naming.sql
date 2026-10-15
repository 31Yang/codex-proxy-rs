-- 统一领域名称和统计时间粒度，仅重命名现有对象，不复制数据或重建索引
do $$
declare
    names record;
    constraint_name record;
    index_name record;
    table_oid oid;
begin
    for names in
        select * from (values
            ('client_key_budget_windows', 'client_api_key_budget_windows'),
            ('client_key_charge_events', 'client_api_key_charge_events'),
            ('authorization_receipts', 'provider_authorization_receipts'),
            ('plugin_group_resources', 'plugin_account_group_resources'),
            ('plugin_key_resources', 'plugin_client_api_key_resources'),
            ('request_analytics_hourly', 'request_analytics_1h'),
            ('request_analytics_daily_counts', 'request_analytics_1d_counts')
        ) as renamed(old_name, new_name)
    loop
        table_oid := format('%I', names.old_name)::regclass;
        execute format('alter table %I rename to %I', names.old_name, names.new_name);

        -- 主键和唯一约束改名会同步改名其索引；目录查询也覆盖数据库生成的约束名
        -- LIKE 复制的非空约束可能沿用十五分钟表的前缀，仅修正小时表自身的约束
        for constraint_name in
            select conname,
                case when starts_with(conname, names.old_name || '_')
                    then names.old_name else 'request_analytics_15m' end as prefix
            from pg_constraint
            where conrelid = table_oid
              and (starts_with(conname, names.old_name || '_')
                or (names.old_name = 'request_analytics_hourly'
                    and starts_with(conname, 'request_analytics_15m_')))
            order by conname
        loop
            execute format('alter table %I rename constraint %I to %I',
                names.new_name, constraint_name.conname,
                names.new_name || substr(constraint_name.conname, length(constraint_name.prefix) + 1));
        end loop;

        for index_name in
            select c.relname from pg_index i join pg_class c on c.oid = i.indexrelid
            where i.indrelid = table_oid and starts_with(c.relname, names.old_name || '_')
            order by c.relname
        loop
            execute format('alter index %I rename to %I', index_name.relname,
                names.new_name || substr(index_name.relname, length(names.old_name) + 1));
        end loop;
    end loop;
end
$$;

alter trigger request_analytics_hourly_daily_counts on request_analytics_1h
    rename to request_analytics_1h_1d_counts;
alter function sync_request_analytics_daily_counts() rename to sync_request_analytics_1d_counts;

-- PL/pgSQL 函数体中的表名不会随表重命名自动改写，保留原有日计数增减语义
create or replace function sync_request_analytics_1d_counts() returns trigger language plpgsql as $$
declare
    old_day timestamptz;
    new_day timestamptz;
    delta bigint;
begin
    if TG_OP <> 'INSERT' then
        old_day := date_bin(interval '1 day',OLD.bucket_start,timestamptz '2000-01-01 UTC');
    end if;
    if TG_OP <> 'DELETE' then
        new_day := date_bin(interval '1 day',NEW.bucket_start,timestamptz '2000-01-01 UTC');
    end if;
    if TG_OP = 'UPDATE' and
        (old_day,OLD.collection,OLD.dimensions[1],OLD.outcome,OLD.schema_version,OLD.histogram_version)
        is not distinct from
        (new_day,NEW.collection,NEW.dimensions[1],NEW.outcome,NEW.schema_version,NEW.histogram_version) then
        if NEW.collection in ('account','key') then
            delta := NEW.request_count - OLD.request_count;
            if delta <> 0 then
                update request_analytics_1d_counts set request_count=request_count+delta
                where collection=NEW.collection and bucket_start=new_day and dimension=NEW.dimensions[1]
                    and outcome=NEW.outcome and schema_version=NEW.schema_version and histogram_version=NEW.histogram_version;
            end if;
        end if;
        return null;
    end if;
    if TG_OP <> 'INSERT' and OLD.collection in ('account','key') then
        update request_analytics_1d_counts set request_count=request_count-OLD.request_count
        where collection=OLD.collection and bucket_start=old_day and dimension=OLD.dimensions[1]
            and outcome=OLD.outcome and schema_version=OLD.schema_version and histogram_version=OLD.histogram_version;
        delete from request_analytics_1d_counts
        where collection=OLD.collection and bucket_start=old_day and dimension=OLD.dimensions[1]
            and outcome=OLD.outcome and schema_version=OLD.schema_version and histogram_version=OLD.histogram_version
            and request_count=0;
    end if;
    if TG_OP <> 'DELETE' and NEW.collection in ('account','key') then
        insert into request_analytics_1d_counts values(new_day,NEW.collection,NEW.dimensions[1],NEW.outcome,NEW.schema_version,NEW.histogram_version,NEW.request_count)
        on conflict(collection,bucket_start,dimension,outcome,schema_version,histogram_version)
        do update set request_count=request_analytics_1d_counts.request_count+excluded.request_count;
    end if;
    return null;
end;
$$;

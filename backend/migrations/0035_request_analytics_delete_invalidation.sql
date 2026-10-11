-- 空清理不更新统计代次，避免与启动回填的快照事务发生无效写冲突
create or replace function invalidate_deleted_request_analytics() returns trigger language plpgsql as $$
begin
    if exists (select 1 from deleted_requests) then
        update request_analytics_build_state set generation = generation + 1 where singleton;
    end if;
    return null;
end
$$;

drop trigger request_analytics_delete_invalidation on model_requests;
create trigger request_analytics_delete_invalidation after delete on model_requests
referencing old table as deleted_requests
for each statement execute function invalidate_deleted_request_analytics();

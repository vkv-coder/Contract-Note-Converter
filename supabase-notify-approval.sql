-- Emails the user when their cn_users.status flips to 'approved' (the field
-- checked at login that unlocks access — pending.html is shown otherwise).
-- admin.html's updateStatus() calls the cn_admin_update_status RPC, which
-- updates this column — no application code ever emailed the user, only
-- cn_signup_notify (AFTER INSERT) exists, notifying the admin of a new
-- signup, not the user of their approval.
-- Same pattern as derasar-boli/DealLagi/reminder — shared Cloudflare Worker
-- email relay (telegram-notify.unigoods2026.workers.dev, action:"sendEmail").

create or replace function cn_notify_approval() returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.status = 'approved' and OLD.status is distinct from 'approved' then
    if NEW.email is not null then
      perform net.http_post(
        url := 'https://telegram-notify.unigoods2026.workers.dev/',
        headers := '{"Content-Type":"application/json"}'::jsonb,
        body := jsonb_build_object(
          'action', 'sendEmail',
          'to', NEW.email,
          'fromName', 'Contract Note Converter',
          'subject', 'Your Contract Note Converter account is approved',
          'html', '<p>Hi,</p>'
            || '<p>Your account on <b>Contract Note Converter</b> has been approved. You can now log in and start using the app:</p>'
            || '<p><a href="https://vkv-coder.github.io/Contract-Note-Converter/">https://vkv-coder.github.io/Contract-Note-Converter/</a></p>'
            || '<p style="font-size:13px;color:#666;">Questions? Contact vkvcoder.support@gmail.com</p>'
        )
      );
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists cn_users_notify_approval on cn_users;
create trigger cn_users_notify_approval
after update on cn_users
for each row execute function cn_notify_approval();

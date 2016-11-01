select distinct
  users.id,
  institutions.campus,
  users.first_name,
  users.last_name,
  users.email,
  users.uid,
  users.provider,
  users.oauth_token
from
  users,
  institutions
where
  users.institution_id = institutions.id and
  users.id in (
    select distinct user_id from records
  )
;

select distinct
  records.id,
  records.title,
  records.local_id,
  users.id,
  institutions.campus,
  users.first_name,
  users.last_name,
  users.email,
  users.uid,
  users.provider,
  users.oauth_token
from
  records,
  users,
  institutions
where
  users.id = records.user_id and
  users.institution_id = institutions.id


select distinct
  records.id as record_id,
  records.title,
  (
    select
      count(records2.title)
    from
      records records2
    where
      trim(records2.title) = trim(records.title)
    group by
      records2.title
  ) as title_count,
  records.local_id,
  users.id as user_id,
  institutions.campus,
  users.first_name,
  users.last_name,
  users.email,
  users.uid,
  users.provider,
  users.oauth_token
from
  records,
  users,
  institutions
where
  users.id = records.user_id and
  users.institution_id = institutions.id

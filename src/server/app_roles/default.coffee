###
  Starts web and static serving, API, OT processing, and so on.
  Role started by default (when no APP_ROLES env var provided).
###

# defaults for development
process.env.FRONTEND_QUEUE_SUFFIX = 'app1' if not process.env.FRONTEND_QUEUE_SUFFIX
process.env.BACKEND_ID_RANGE = '0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f' if not process.env.BACKEND_ID_RANGE
require('./web_main')
require('./web_authentication')
require('./web_export')
require('./wave')
require('./wave_backend')
require('./web_file')
require('./web_hangout')
require('./web_accounts_merge')
require('./web_tag')
require('./web_drive')

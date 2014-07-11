###
  Role starts OT backend (listens AMQP for operations and sequentially processes them).
  Requires BACKEND_ID_RANGE env variable to be set (for example '0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f').
###
Conf = require('../conf').Conf
Conf.setServerAsOtBackend()
require('../wave/processor_backend')
require('../blip/processor_backend')

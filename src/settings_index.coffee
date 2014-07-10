window.createTeamExports = require('./client/account_setup_wizard/create_team');

window.waveParticipantsConstantsExports = require('./client/wave/participants/constants');

waveProcessorExports = require('./client/wave/processor');
waveProcessorExports.instance = new waveProcessorExports.WaveProcessor(null);
waveProcessorExports.instance.updateUserContacts(window.userContacts || []);

accountSetupProcessorExports = require('./client/account_setup_wizard/processor');
accountSetupProcessorExports.instance = new accountSetupProcessorExports.AccountSetupProcessor(null);
window.accountSetupProcessorExports = accountSetupProcessorExports;

window.accountTypeSelectExports = require('./client/account_setup_wizard/account_type_select')

window.enterpriseRequestExports = require('./client/account_setup_wizard/enterprise_request')

window.userModelExports = require('./client/user/models')

window.updateContacts = (contacts) =>
    # Получаем объект не напрямую, а через json, поскольку IE удаляет объекты, созданные в другом окне
    contacts = JSON.parse(contacts)
    waveProcessorExports.instance.updateUserContacts(contacts)

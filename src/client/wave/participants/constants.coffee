ROLE_OWNER = 1
ROLE_EDITOR = 2
ROLE_COMMENTATOR = 3
ROLE_READER = 4
ROLE_NO_ROLE = 65536

ROLES = [
    {name: 'Owner', id: ROLE_OWNER} #владелец топика
    {name: 'Editor', id: ROLE_EDITOR}  #редактор топика (крутой чувак, может все)
    {name: 'Commenter', id: ROLE_COMMENTATOR} #участник топика
    {name: 'Reader', id: ROLE_READER} #читатель топика
]

module.exports = {ROLES, ROLE_OWNER, ROLE_EDITOR, ROLE_COMMENTATOR, ROLE_READER, ROLE_NO_ROLE}
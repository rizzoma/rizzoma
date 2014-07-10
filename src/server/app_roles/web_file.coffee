###
Роль для приложения сервиса s3.
Загрузка и раздача файлов
###

express = require('express')
app = require('./web_base').app
FilesView = require('../file/view').FilesView

BASE_URL = '/files/'
GET_REMAINING_SPACE_URL = BASE_URL + 'getremainingspace/'
{
    REDIRECT_URL
    THUMBNAIL_REDIRECT_URL
} = require('../file/constants')

#app.get REMOVE_URL

app.post BASE_URL, FilesView.putFile
app.get GET_REMAINING_SPACE_URL, FilesView.getRemainingSpace
app.get "#{THUMBNAIL_REDIRECT_URL}:fileId", FilesView.thumbnailLinkRedirect
app.get "#{REDIRECT_URL}:fileId/:fake?", FilesView.fileLinkRedirect


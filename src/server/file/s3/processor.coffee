async = require('async')
fs = require('fs')
awssum = require('awssum')
amazon = awssum.load('amazon/amazon')
s3Service = awssum.load('amazon/s3')
StorageProcessor = require('../storage_processor').StorageProcessor

class S3StorageProcessor extends StorageProcessor
    constructor: (accessKeyId, secretAccessKey, awsAccountId, region, @_bucketName, @_linkExpiration) ->
        @_s3 = new s3Service(accessKeyId, secretAccessKey, awsAccountId, region)

    putFile: (path, storagePath, type, callback) =>
    #putFile: (path, storagePath, options = {ContentType: '', StorageClass: 'STANDARD|REDUCED_REDUNDANCY'}, callback) =>
        ###
        Загружает файл на s3.
        @param path: string - путь к загружаемому файлу в файловой системе
        @param name: string - имя файла на s3
        @param type: string - Mime-type
        @param callback: function
        ###
        tasks = [
            async.apply(fs.readFile, path)
            (buffer, callback) =>
                options =
                    BucketName: @_bucketName
                    ObjectName: storagePath
                    ContentLength: buffer.length
                    ContentType: type or 'binary/octet-stream'
                    Body: buffer
                @_s3.PutObject(options, (err) ->
                    callback(err)
                )
        ]
        async.waterfall(tasks, callback)

    deleteFile: (storagePath, callback) =>
        ###
        Удаляет файл с s3.
        @param name: string - имя файла на s3
        @param callback: function
        ###
        options =
            BucketName: @_bucketName
            ObjectName: storagePath
        @_s3.DeleteObject(options, callback)

    getLink: (storagePath, notProtected=false) =>
        ###
        Поучает ссылку на s3.
        @param storagePath: string - имя файла на s3
        @param notProtected: boolean - если передан, вернет незащищённую (неподписанную) ссылку.
        @param callback: function
        ###
        link = "https://s3.amazonaws.com/#{@_bucketName}/#{storagePath}"
        return link if notProtected
        expires = parseInt(Date.now() / 1000) + @_linkExpiration
        options =
            method: 'GET'
            headers:
                Date: expires + ''
            params: []
        args =
            BucketName: @_bucketName
            ObjectName: storagePath
        strToSign = @_s3.strToSign(options, args)
        signature = @_s3.signature(strToSign)
        return "#{link}?Expires=#{expires}&AWSAccessKeyId=#{@_s3.accessKeyId()}&Signature=#{encodeURIComponent(signature)}"

exports.S3StorageProcessor = S3StorageProcessor

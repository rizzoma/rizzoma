StorageProcessor = require('../storage_processor').StorageProcessor
Conf = require('../../conf').Conf
fs = require('fs')
path_module = require('path')

class LocalStorageProcessor extends StorageProcessor
        
    putFile: (path, storagePath, type, callback) ->
        # add prefix directory to path
        complete_storage_path = "data/uploaded-files/#{storagePath}"
        # ensure directory exists
        # TODO(Robin): make async like http://stackoverflow.com/a/21196961/1469195 
        # or use mkdirp module from npm
        mkdirpSync(path_module.dirname(complete_storage_path))
        # Copy the file
        copyFile(path, complete_storage_path, callback)

    # Adapted from http://stackoverflow.com/a/24311711/1469195
    mkdirpSync = (dirpath) ->
        parts = dirpath.split(path_module.sep)
        i = 1
        while i <= parts.length
          try
              fs.mkdirSync(path_module.join.apply(null, parts.slice(0, i)))
          catch e
              if (e.code != 'EEXIST') then throw e
          i++
        return

    # from http://stackoverflow.com/a/21995878/1469195
    copyFile = (path, storagePath, callback) ->
        cbCalled = false
        rd = fs.createReadStream(path)
        done = (err) ->
            if !cbCalled
                callback(err)          
                cbCalled = true
            return
        
        rd.on('error', done)
        wr = fs.createWriteStream(storagePath)
        wr.on('error', done)
        wr.on('close', (ex) ->
            done()
            return
        )
        rd.pipe(wr)

    deleteFile: (storagePath, callback) ->
        # TODO(Robin): delete empty directories?
        complete_storage_path = "data/uploaded-files/#{storagePath}"
        fs.unlink(complete_storage_path, callback)
  
    getLink: (storagePath, notProtected=false) ->
        #  files accessible trough /f/... defined in src/server/app_roles/web_main.coffee
        return "/f/#{storagePath}"

exports.LocalStorageProcessor = LocalStorageProcessor
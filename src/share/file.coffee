class FileStatus
    @ERROR = 'ERROR'
    @UPLOADING = 'UPLOADING'
    @PROCESSING = 'PROCESSING'
    @READY = 'READY'

class Error
    @FILE_UPLOAD_LIMIT_EXCEEDED_ERROR = 'FILE_UPLOAD_LIMIT_EXCEEDED_ERROR'

exports.FileStatus = FileStatus

exports.JPEG_TYPE = JPEG_TYPE = 'image/jpeg'
exports.BMP_TYPE = BMP_TYPE = 'image/bmp'
exports.GIF_TYPE = GIF_TYPE = 'image/gif'
exports.PNG_TYPE = PNG_TYPE = 'image/png'

exports.BrowserSupportedImageTypes = [BMP_TYPE, JPEG_TYPE, GIF_TYPE, PNG_TYPE]
exports.Error = Error

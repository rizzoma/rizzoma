exports.point = point = (x,y) -> return {x:x; y:y}

exports.orthoRect = (minx,miny,maxx,maxy) -> return {min:point(minx,miny), max:point(maxx,maxy)}

exports.orthoRectByCenterAndSize = (cx,cy,sx,sy) ->
    minx = cx-sx/2
    miny = cy-sy/2
    return {min:point(minx,miny), max:point(minx+sx,miny+sy)}

exports.isPointInOrthoRect = (point, rect) ->
    for i in ['x','y']
        if point[i]<rect.min[i] || point[i]>rect.max[i]
            return false;
    return true;
    
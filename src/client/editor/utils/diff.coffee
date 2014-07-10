
dmp = new diff_match_patch()
dmp.Diff_Timeout = 0.02

module.exports.getOpsFromDiff = (oldText, newText, params, offset) ->
    ops = []
    elOffset = 0
    diff = dmp.diff_main(oldText, newText)
    for d in diff
        switch d[0]
            when DIFF_DELETE
                ops.push({p: offset + elOffset, params: params, td: d[1]})
                continue
            when DIFF_INSERT
                ops.push({p: offset + elOffset, params: params, ti: d[1]})
            else
        elOffset += d[1].length
    ops

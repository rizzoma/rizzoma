var couchapp = require('couchapp');

doc = {
    _id: "_design/stat_import",
    language: "javascript",
    views: {}
};

doc.views.imported_by_date = {
    map: function (doc) {
        if(!doc.lastImportingTimestamp) return;
        if(!doc.type || doc.type != 'WaveImportData') return;
        var d=new Date(doc.lastImportingTimestamp*1000),
            dy=d.getUTCFullYear(),
            dm=d.getUTCMonth()+1,
            dd=d.getUTCDate();
        emit([dy, dm, dd], {pc: doc.participants.length, bc: Object.keys(doc.blipIds).length});
    },
    reduce: function (keys, values, rereduce) {
        groups = {cc: 0,
                  pc: {less5: 0,
                       f6to10: 0,
                       f11to20: 0,
                       more20: 0},
                  bc: {less10: 0,
                       f11to30: 0,
                       f31to50: 0,
                       more50: 0}};
        if (rereduce) {
            for (var i = values.length-1; i >= 0; i--) {
                v = values[i]
                groups.cc += v.cc;

                groups.pc.less5 += v.pc.less5;
                groups.pc.f6to10 += v.pc.f6to10;
                groups.pc.f11to20 += v.pc.f11to20;
                groups.pc.more20 += v.pc.more20;

                groups.bc.less10 += v.bc.less10;
                groups.bc.f11to30 += v.bc.f11to30;
                groups.bc.f31to50 += v.bc.f31to50;
                groups.bc.more50 += v.bc.more50;
            }
            return groups;
        }
        else {
            for (var i = values.length-1; i >= 0; i--) {
                v = values[i];
                groups.cc++;
                if (v.pc<6) groups.pc.less5++;
                if (v.pc>5 && v.pc<11) groups.pc.f6to10++;
                if (v.pc>10 && v.pc<21) groups.pc.f11to20++;
                if (v.pc>20) groups.pc.more20++;

                if (v.bc<11) groups.bc.less10++;
                if (v.bc>10 && v.bc<31) groups.bc.f11to30++;
                if (v.bc>30 && v.bc<51) groups.bc.f31to50++;
                if (v.bc>50) groups.bc.more50++;
            }
            return groups;
        }
    }
};

module.exports = doc;
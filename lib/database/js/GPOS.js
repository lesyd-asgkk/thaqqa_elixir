import { FontManager, RegExp_Khhyl } from "../deps.js";

class GPOSManager {
    static setGPOSColumnAll(font) {
        GPOSManager.setGPOSColumn(null, font);
    }
    static setGPOSColumn(id, font) {
        const table_ = FontManager.getFont(font).getTable("GPOS");
        const GPOSdata = id == null
            ? table_.dataList
            : table_.getData({ ID: id });
        try {
            GPOSdata.forEach((i) => {
                const r_ = new RegExp_Khhyl(i.getVal("Name"), {}).ParseRegExp()
                    .toNormalRegExp();
                table_.rewriteData({ ID: i.getVal("ID") }, { Parsed: r_ });
            });
        } catch (e) {
            return new Error(e.message);
        }
    }
    static getGPOS(param, font) {
        if (param instanceof RegExp) param = { Name: param };
        if (typeof param == "string") param = { Name: param };

        const table_ = FontManager.getFont(font).getTable("GPOS");
        const data = table_.getData(param);
        return data;
    }
    static rewriteGPOS(param, param2, font) {
        if (param instanceof RegExp) param = { Name: param };
        if (typeof param == "string") param = { Name: param };

        if (typeof param2 == "string") param2 = { Name: param2 };
        const table_ = FontManager.getFont(font).getTable("GPOS");
        const GPOS_a = GPOSManager.getGPOS(param.Name);
        const GPOS_b = GPOSManager.getGPOS(param.Name);
        if (param.Name != null && GPOS_a.length >= 2 && param2.Name != null) {
            throw new Error("変更対象がありません");
        }
        if (param2.Name != null && GPOS_b.length != 0) {
            throw new Error("変更後に重複が発生します");
        }

        const b = table_.rewriteData(param, param2, -1);
        return b;
    }

    static deleteGPOS(param, font, safety) {
        safety ??= true;
        if (typeof param == "string") param = { Name: param };
        if (param instanceof RegExp) param = { Name: param };

        if (safety && GPOSManager.getGPOS(param).length > 1) {
            return new Error(
                "削除対象が2つ以上あります。まとめて削除したい場合はsafetyをfalseに指定してください",
            );
        }
        const table_ = FontManager.getFont(font).getTable("GPOS");

        const data = table_.deleteData(param, 1);
        return data;
    }
    static createGPOS(param, font) { //
        if (typeof param == "string") param = { Name: param };
        if (GPOSManager.getGPOS(param).length != 0) {
            return new Error(param + "はすでに存在しています");
        }
        if (typeof param == "string") {
            param = {
                Name: param,
                Pattern: "u",
                Pattern_sub: "DIAC",
                OffsetX0: 0,
                OffsetY0: 0,
                OffsetX1: 0,
                OffsetY1: 0,
                Priority: 0,
            };
        }
        const table_ = FontManager.getFont(font).getTable("GPOS");
        table_.createData(param);
    }

    static gpos(text, vec, rule, font) {
        //gposIN,gposINEXの内部処理について
        //真面目に処理すると膨大すぎてパンクする。

        //そこで
        //まず「常識的に取りうる範囲の全てのoffset集」を計算しておく
        //非常識な値のみ個別計算
        //これで多分解決

        const ans = { x0: 0, y0: 0, x1: 0, y1: 0 };
        const GPOSdata = GPOSManager.getGPOS({
            Pattern: (vec == 0 ? /(u|v)/ : /(u|h)/),
            Pattern_sub: rule,
        }, font);
        GPOSdata.forEach((i) => {
            const r_fin = new RegExp(
                (rule == "EX" ? "^" : "") + i.getVal("Parsed") +
                    (rule == "EX" ? "$" : ""),
                "g",
            );
            if (text.match(r_fin) != null) {
                ans.x0 += i.getVal("OffsetX0");
                ans.y0 += i.getVal("OffsetY0");
                ans.x1 += i.getVal("OffsetX1");
                ans.y1 += i.getVal("OffsetY1");
            }
        });
        return ans;
    }
}

export { GPOSManager };

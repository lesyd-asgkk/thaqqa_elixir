import { FontManager, RegExp_Khhyl } from "../deps.js";

class GSUBManager {
    static getGSUB(param) {
        if (param instanceof RegExp) param = { Name: param.Name };
        if (typeof param == "string") param = { Name: param };
        const table_ = FontManager.getStaticTable("GSUB");
        return table_.getData(param);
    }
    static rewriteGSUB(param, param2) {
        if (param instanceof RegExp) param = { Name: param.Name };
        if (typeof param == "string") param = { Name: param };

        if (typeof param2 == "string") param2 = { Name: param2 };
        const table_ = FontManager.getStaticTable("GSUB");

        const GSUB_a = GSUBManager.getGSUB(param.Name);
        const GSUB_b = GSUBManager.getGSUB(param.Name);
        if (param.Name != null && GSUB_a.length >= 2 && param2.Name != null) {
            throw new Error("変更後に重複が発生します");
        }
        if (param2.Name != null && GSUB_b.length != 0) {
            throw new Error("変更後に重複が発生します");
        }
        const b = table_.rewriteData(param, param2, -1);
        return b;
    }
    static deleteGSUB(param, safety) {
        safety ??= true;
        if (param instanceof RegExp) param = { Name: param.Name };
        if (typeof param == "string") param = { Name: param };

        if (safety && GSUBManager.getGSUB(param).length > 1) {
            return new Error(
                "削除対象が2つ以上あります。まとめて削除したい場合はsafetyをfalseに指定してください",
            );
        }
        const table_ = FontManager.getStaticTable("GSUB");
        const data = table_.deleteData(param, 1);
        return data;
    }
    static createGSUB(param) {
        if (typeof param == "string") param = { Name: param };
        if (GSUBManager.getGSUB(param).length != 0) {
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
        const table_ = FontManager.getStaticTable("GSUB");
        table_.createData(param);
    }
    static setGSUBColumnAll() {
        GSUBManager.setGSUBColumn();
    }
    static setGSUBColumn(id) {
        const table_ = FontManager.getStaticTable("GSUB");
        const GSUBdata = id == null
            ? table_.dataList
            : table_.getData({ ID: id });

        try {
            GSUBdata.forEach((i) => {
                const r_ = new RegExp_Khhyl(i.getVal("Name"), {}).ParseRegExp()
                    .toNormalRegExp();
                table_.rewriteData({ ID: i.getVal("ID") }, { Parsed: r_ });
            });
        } catch (e) {
            return new Error(e.message);
        }
    }
    static gsub(text, vec) {
        const table_ = FontManager.getStaticTable("GSUB");
        const array = table_.getData({
            Pattern: (vec == 0 ? /(u|v)/ : /(u|h)/),
        });

        const sortalg = function (first, second) { //Priorityの小さい順に並び替える
            const l_ = Math.sign(
                first.getVal("Order") - second.getVal("Order"),
            );
            return l_ != 0
                ? l_
                : Math.sign(
                    first.getVal("Priority") - second.getVal("Priority"),
                );
        };
        array.sort(sortalg);
        array.forEach((i) => {
            text = text.replaceAll(
                new RegExp(i.getVal("Parsed"), "g"),
                i.getVal("NameAlt"),
            );
        });
        return text;
    }
}

export { GSUBManager };

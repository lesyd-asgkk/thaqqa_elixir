import { FontManager,RegExp_Khhyl } from "../deps.js";

class F_GSUBManager {
    static getFGSUB(param,font) {
        if(param instanceof RegExp) param = {Name:param};
        if(typeof param == "string") param = {Name:param};

            const table_ = FontManager.getFont(font).getTable("F_GSUB");
            return table_.getData(param);
            
        }
    static rewriteFGSUB(param,param2,font){
        if(param instanceof RegExp) param = {Name:param};
        if(typeof param == "string") param = {Name:param};
        if(typeof param2 == "string") param2 = {Name:param2};
        const table_ = FontManager.getFont(font).getTable("F_GSUB");

        const GSUB_a = F_GSUBManager.getFGSUB(param.Name,font);
        const GSUB_b = F_GSUBManager.getFGSUB(param.Name,font);
            if(param.Name != null && GSUB_a.length >= 2 && param2.Name!=null)throw new Error("変更後に重複が発生します");
            if(param2.Name != null && GSUB_b.length != 0)throw new Error("変更後に重複が発生します");
        const b = table_.rewriteData(param,param2,-1);
        return b;
    }
    static deleteFGSUB(param,font,safety){
        safety ??= true;
        if(param instanceof RegExp) param = {Name:param};
        if(typeof param == "string") param = {Name:param};

        if(safety && F_GSUBManager.getFGSUB(param,font).length > 1) return new Error("削除対象が2つ以上あります。まとめて削除したい場合はsafetyをfalseに指定してください");
        const table_ = FontManager.getFont(font).getTable("F_GSUB");
        const data = table_.deleteData(param,1);
        return data;
    }
    static createFGSUB(param,font){
        if(typeof param == "string") param = {Name:param};
        
        if(F_GSUBManager.getFGSUB(param,font).length != 0) return new Error(param+"はすでに存在しています");
        if(typeof param == "string"){
            param ={Name: param, Pattern:"u",Pattern_sub:"DIAC",OffsetX0: 0, OffsetY0: 0,OffsetX1: 0,OffsetY1: 0, Priority:0};
        }
        const table_ = FontManager.getFont(font).getTable("F_GSUB");
        table_.createData(param);
    }
    static setFGSUBColumnAll(font){
        F_GSUBManager.setFGSUBColumn(font);
    }
    static setFGSUBColumn(id,font){
        const table_ = FontManager.getFont(font).getTable("F_GSUB");
        const GSUBdata = id==null?table_.dataList:table_.getData( {ID:id});
        GSUBdata.forEach((i)=>{const r_ = new RegExp_Khhyl(i.getVal("Name"),{}).ParseRegExp().toNormalRegExp();
        table_.rewriteData({ID:i.getVal("ID")},{Parsed:r_});});
     }
    static fgsub(text,vec,font){
        const table_ = FontManager.getFont(font).getTable("F_GSUB");
        const array = table_.getData({Pattern:(vec==0?/(u|v)/:/(u|h)/)});
        const sortalg = function(first, second ){//Priorityの大きい順に並び替える
            const l_ = Math.sign(first.getVal("Order")-second.getVal("Order"));
            return l_!=0?l_:Math.sign(first.getVal("Priority")-second.getVal("Priority"));
            }
        array.sort(sortalg);
        array.forEach((i)=>{if(typeof i.getVal("Name") == "string"){ text = text.replaceAll(new RegExp(i.getVal("Parsed"), "g"),i.getVal("NameAlt"));}})
    return text;
    }
}

export{F_GSUBManager};
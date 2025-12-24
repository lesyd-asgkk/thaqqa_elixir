import { FontManager } from "../deps.js"; //,DataTable,Data
class LetterManager{
    static #tablelist_name_ = ["VOWEL","CONSONANT","DIACRITIC_C","DIACRITIC_V","PUNCTUATION","DIACRITIC_P"];
    static getLetter(param){
        const t = LetterManager.#tablelist_name_.map((i)=>FontManager.getStaticTable(i));
        if(param instanceof RegExp) param = {Name:param};
        if(typeof param == "string") param = {Name:param};

        const ans = [];
        
        for(const i of t){
            if(i instanceof Error){throw i;}
            const data = i.getData(param);
            data.forEach((i)=>ans.push(i));
        }
        return ans;
    }
    static rewriteLetter(param,param2){
        const t = LetterManager.#tablelist_name_.map((i)=>FontManager.getStaticTable(i));
        if(param instanceof RegExp) param = {Name:param};
        if(typeof param == "string") param = {Name:param};

        if(typeof param2 == "string") param2 = {Name:param2};

        if(param.Name != null && LetterManager.getLetter(param).length >= 2 && param2.Name!=null)throw new Error("変更後に重複が発生します");
        if(param2.Name != null && LetterManager.getLetter(param2).length != 0)throw new Error("変更後に重複が発生します");
        const ans = [];
        for(const i of t){
            const b = i.rewriteData(param,param2,-1);
            ans.push(b);
        }
        return ans;
    }
    static deleteLetter(param,safety){
        const t = LetterManager.#tablelist_name_.map((i)=>FontManager.getStaticTable(i));
        safety ??= true;
        if(param instanceof RegExp) param = {Name:param};
        if(typeof param == "string") param = {Name:param};
        
        if(safety && LetterManager.getLetter(param).length > 1) throw new Error("削除対象が2つ以上あります。まとめて削除したい場合はsafetyをfalseに指定してください");
        
        const ans = [];
        for(const i of t){
            const data = i.deleteData(param,1);
            ans.push(data);
        }
        return ans;
    }
    static createLetter(param,type){//
        try{
        if(LetterManager.getLetter(param).length != 0) throw new Error(param+"はすでに存在しています");
        const TYPE = {["\\c"]:"CONSONANT",["\\v"]:"VOWEL",["\\p"]:"PUNCTUATION",
        ["\\cd"]:"DIACRITIC_C",["\\vd"]:"DIACRITIC_V",["\\pd"]:"DIACRITIC_P"};
        let param2;
        if(typeof param == "string"){
            const TEMPLATE = {["CONSONANT"]:{
                Name: param, LoadName: param,
                OnsetGlyphNum: 1, CodaGlyphNum:1,
                isBondAsFirst: true, isBondAsLast:true
                ,Order:0},["VOWEL"]:{Name:param,LoadName:param,
                SolGlyphNum: 1, InitGlyphNum: 1, MidGlyphNum: 2, FinGlyphNum: 4,
                isVowel: true, isNullVowel:false, hasGreedyBond: true, isBondtoPrev: true, isBondtoNext: true
                ,Order:0},["PUNCTUATION"]:{
                    Name: param, LoadName: param,
                     GlyphNum: 1,IsNewline:false,Order:0
                     },
            ["DIACRITIC_C"]:{Name: param, LoadName: param, //'はc,分離符はx
            OnsetGlyphNum: 1, CodaGlyphNum: 1,x_Align:0,y_Align:0
            ,Order:0},
            ["DIACRITIC_V"]:{Name:param,LoadName:param,
                SolGlyphNum: 1, InitGlyphNum: 1, MidGlyphNum: 2, FinGlyphNum: 4,Order:0,x_Align:0,y_Align:0},
            ["DIACRITIC_P"]:{
                Name: param, LoadName: param,
                 GlyphNum: 1
                 ,Order:0,x_Align:0,y_Align:0}};
                 type = TYPE[type]  ?? type;
            param2 = TEMPLATE[type];
        }
        else param2 = param;
        type = TYPE[type]  ?? type;
        const table = FontManager.getStaticTable(type);
            table.createData(param2);
    }catch(e){throw(e);}
    }
}

export {LetterManager};
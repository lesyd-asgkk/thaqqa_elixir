
import { FontManager,SVG,Path,Point,RegExp_Khhyl,GlyphManager,GPOSManager,LetterManager} from "./deps.js";


class GlyphArray{
    constructor(name,vec,font,iswrap,box,pos,alg){
        this.name=name;
        this.font=font;
        this.path = []; //pathに改名予定、new Path();にもする予定
        this.glyphList = [];//Glyphの配列 入れ子にします
        this.attribute = {};//(将来に属性を付ける場合の為。)
        this.position = {x:pos.x??0,y:pos.y??0};//（parentに対するthisのoffset）
        this.aligment = {x:alg.x??0,y:alg.y??0};
        this.vec = vec; //-1(右から左),0(上から下),1(左から右)
        this.box = box;//{top:0,right:0,bottom:0,left:0};
        this.iswrap = iswrap;// 端で折り返すかどうか(将来用)
        this.initSvg();
    }
    initSvg(){
        //
        const r_ = new RegExp_Khhyl("(L())(L())",{}).ParseRegExp().toNormalRegExp();
        const text = this.name.replaceAll(new RegExp(r_, "g"),"$1Sep()$2").replaceAll(new RegExp(r_, "g"),"$1Sep()$2");

        const pathData = text.split("Sep()");
        pathData.forEach((i)=> this.glyphList.push(new Glyph(i , this.vec,this.font)))
        if(this.vec == -1) this.glyphList.reverse();
    }

    #to_em(n) {  //指定した大きさnに変換する為に倍率をかける関数
        const textdata = FontManager.getFont(this.font).getTable("FONTDATA").dataList[0].valueList; 
        return n/(this.vec==0?textdata.WidthV:textdata.Height);
    }

    
    #toPath_horizontal(defaultsize,_prev,_next){
        const textdata = FontManager.getFont(this.font).getTable("FONTDATA").dataList[0].valueList;
        const newline_list = FontManager.getStaticTable("PUNCTUATION").getData({"IsNewline":true}).map((i) =>i.getVal("Name"));

        let x = this.position.x; let y = this.position.y;
        this.path = Path.fromPosition(x,y);//初期位置に移動

        const is_dir_right = this.vec == 1;
        for(let i = 0;i<this.glyphList.length;i++){
            const size_em = this.#to_em(defaultsize); //将来的に文字サイズを可変にしたいので、単にsize_emと命名。
            const size = defaultsize;//同上

            const glyph_path = this.glyphList[i].toPathAbsolute(textdata.Height,0.5+GPOSManager.gpos(this.glyphList[i].fullname,this.vec,"INEX",this.font).y1/textdata.Height).rescale(size_em);
            const glyph_width = (!textdata.isWidthHRel ? size*textdata.WidthV:glyph_path.getLeft()+glyph_path.getRight()+size*textdata.WidthV)/textdata.Height;
                
            let gap_left = 0;let gap_right = 0;


            const tmp_for_gap = GPOSManager.gpos(this.glyphList[i].fullname,this.vec,"INEX",this.font);
            gap_right += tmp_for_gap.x1; gap_left += tmp_for_gap.x0;

            //左側の隙間。前の文字と照らし合わせて調整
            gap_left += GPOSManager.gpos( (i == 0 ? (_prev??"Null()") :this.glyphList[i-1].fullname)+this.glyphList[i].fullname,this.vec,"EX",this.font).x1;

            //右側の隙間。前の文字と照らし合わせて調整
            gap_right += GPOSManager.gpos(this.glyphList[i].fullname+(i != this.glyphList.length-1 ? this.glyphList[i+1].fullname:(_next??"Null()")),this.vec,"EX",this.font).x0;

            x += glyph_width/2 +(is_dir_right?gap_left:gap_right)*size_em;

            this.path.mergePath2(glyph_path,x,y);
            //this.path.concat(Path.fromPosition(x,y)).concat(glyph_path.toRelativeAll()); //文字情報を繋げる

            if(i!=this.glyphList.length-1) x += glyph_width/2 +(is_dir_right?gap_right:gap_left)*size_em;  //最後の文字で無ければ文字の幅/2分だけ進める
            this.glyphList[i].offset = {x,y};  //offsetを指定しておく
            //改行に差し掛かったときの処理。iswrap対応時はここの条件を追加する。
            if(newline_list.indexOf(this.glyphList[i].name)!=-1){   x = 0;y += size*((textdata.Height+textdata.TopGapH)/textdata.Height); }
        }
        this.path.concat(Path.fromPosition(x,y));
    }

    #toPath_vertical(defaultsize,_prev,_next){
        this.path = Path.fromPosition(this.position.x,this.position.y);//初期位置に移動
        let x = this.position.x;
        let y = this.position.y;
        const newline_list = FontManager.getStaticTable("PUNCTUATION").getData({"IsNewline":true}).map((i) =>i.getVal("Name"));
        let isnewline = true;
        for(let i = 0;i<this.glyphList.length;i++){
            //m0 -> gap_above , m1 -> gap_below
            let gap_above = 0;let gap_below = 0;
            const size_em = this.#to_em(defaultsize); //将来的に文字サイズを可変にしたいので、単にsize_emと命名。
            const size = defaultsize;//同上

            const tmp_for_gap = GPOSManager.gpos(this.glyphList[i].fullname,this.vec,"INEX",this.font);
            gap_below += tmp_for_gap.y1; gap_above += tmp_for_gap.y0;

            //上の隙間。前の文字と照らし合わせて調整
            gap_above += GPOSManager.gpos((i == 0 ? (_prev??"Null()") :this.glyphList[i-1].fullname)+this.glyphList[i].fullname,this.vec,"EX",this.font).y1;
            
            //下の隙間。次の文字と照らし合わせて調整
            gap_below += GPOSManager.gpos(this.glyphList[i].fullname+(i != this.glyphList.length-1 ? this.glyphList[i+1].fullname:(_next??"Null()")),this.vec,"EX",this.font).y0;

            //当然、上の隙間の分だけ文字情報がズレるので補正
            y += gap_above*size_em;

            const is_isolated = (this.glyphList[i].type == "P") || (this.glyphList[i].form == "sol");
            const glyph_path = this.glyphList[i].toPathRelative(!is_isolated?-gap_above:0,gap_below).rescale(size_em);
            if(isnewline){ //改行に差し掛かったときの処理。
                y -= ((this.glyphList[i].toPathRelative(0,0).getTop())-gap_above)*size_em;
                isnewline = false;
            }
            this.path.mergePath2(glyph_path,x,y);
            this.glyphList[i].offset = {x,y}; //offsetを指定しておく
            //this.path = this.path.concat(Path.fromPosition(x,y)).concat(glyph_path.toRelativeAll()); //文字情報を繋げる
            y += (this.glyphList[i].toPathRelative(0,0).getBottom()+gap_below)*size_em;      //文字の長さの分＋隙間分下に進める
            if(i+1 != this.glyphList.length){const d2 = this.glyphList[i+1].path;y -= d2.getTop()*size_em;}
                
            
            if(newline_list.indexOf(this.glyphList[i].name)!=-1){  x -= size;y = 0;isnewline = true; }
        }
       this.path.concat(Path.fromPosition(x,y));
    }

    toPath(defaultsize,_prev,_next){//_prevは今後用
        if(this.vec==0){this.#toPath_vertical(defaultsize,_prev,_next);}
        else{this.#toPath_horizontal(defaultsize,_prev,_next);}
        return this.path;
    }

}
class Glyph{
    constructor(name,vec,font){
        this.font = font;
        this.vec = vec;
        this.fullname = name; 
        this.name = ""; 
        this.pathOrigin = new Path(); //ダイアクリティカルマークなしの元のパスデータ。ただし、Sタイプの場合はVowelのダイアクリティカルマークなしのパスデータ
        this.path = new Path(); //pathに改名予定、new Path();にもする予定
        this.val = -1; //異字体の調整用。なにもない場合は設定しない
        this.form = "";//init,mid,fin,solなどの形態指定用
        this.isroot = false;//親がいないかどうか。
        this.parent;//親Glyphの参照
        this.childGlyphList = [];//Glyphの配列 入れ子にします
        this.attribute = {};//(将来用)
        this.size = 16;
        this.type = "";//S,P,C,V,Pd,Cd,Vdのいずれか
        this.offset = {x:0,y:0};//（parentに対するthisのoffset）
        this.gap ={top:0,middle:0,bottom:0}; //上棒、中央、下棒
        this.aligment = {x:0,y:0};
        this.height_vtop = 0;
        this.height_vbottom = 0;
        this.height_bottom = 0;
        this.height_top = 0;
        this.initSvg(name);
        this.toPath();
    }
    initSvg(name){
        const partname = this.#partitionName(name);
        if(partname.length == 0){//これ以上分割不能な場合
            this.isroot = true;
            if( (name ?? "") == ""){this.path = new Path() ,this.aligment = {x:0,y:0};return [];} //this.path = Path.new();
            const form = this.form ?? "";
            const name_ = `${this.name}_${form}_${this.val}`;
            //const dt = (GlyphManager.getSVG(name_,this.font)[0]) ?? "M 0,0";
            const path_temp = Path.parseString((GlyphManager.getSVG(name_,this.font)[0]) ?? "M 0,0").toRelativeAll();//にする予定。
            this.path = path_temp;//this.nameがこれ以上分割できない場合。
            this.pathOrigin = path_temp;
            let off_x = 0; let off_y = 0;
            const letter_temp = LetterManager.getLetter(this.name);
            if(letter_temp.length > 0){
                off_x = letter_temp[0].getVal("x_Align");
                off_y = letter_temp[0].getVal("y_Align");
            }
            this.aligment = {x:off_x,y:off_y};
        }
        else{//分割できたら
            this.isroot = false;
            let x0 = 0;let y0 = 0;let x1;let y1;//いずれもoffsetの為の一時変数
            if(this.type == "S"){
                const k = GPOSManager.gpos(name,this.vec,"IN",this.font);
                x0 = k.x0;y0 = k.y0;x1 = k.x1;y1 = k.y1;
            }
            else{
                const k = GPOSManager.gpos(name,this.vec,"DIAC",this.font);
                x0 = k.x0;y0 = k.y0;
            }
            for(let i = 0 ; i<partname.length;i++){
                const new_glyph = new Glyph(partname[i],this.vec,this.font);
                new_glyph.parent = this;

                if(x1 != null && y1 != null && i == 2)new_glyph.offset = {x:x1,y:y1}; //Sタイプの場合
                else if(x1 != null && y1 != null && i == 0) new_glyph.offset = {x:x0,y:y0}; //これ以上分割不能な場合
                else if(x1 == null && y1 == null && i == 1) new_glyph.offset = {x:x0,y:y0}; //Sタイプ以外で分割可能な場合
                this.childGlyphList.push(new_glyph);
            }
        this.pathOrigin = this.childGlyphList[this.type == "S"?1:0].pathOrigin; //処理の簡略化用に実装。
        } 
    }


    #partitionName(name){ //名前を分割する関数
        this.fullname = name;
        if(name == "") return []; //空の名前なら[]として返す;
        else{ 
            this.type = name.split("(")[0];
            if(name.startsWith("S")){
            //音節ならCo,V,Ccに。空の場合は何も残さない
                const temp = name.match(/\((.+?)\)/)[1].split(",");//S(form,Co,V,Cc)という形を[form,Co,V,Cc]に分割する
                this.glyphname = temp.slice(1).join(","); //glyphnameは「Co,V,Cc」という名前として扱う
                this.form = temp[0];
                const onset = temp[1] == "" ? "" : `C(onset,${temp[1]})`;
                const vowel = temp[2] == "" ? "" : `V(${temp[0]},${temp[2]})`;
                const coda = temp[3] == "" ? "" : `C(coda,${temp[3]})`;
                return [onset,vowel,coda];
            }
            else if(name.startsWith("P")){
                const temp = name.match(/\((.+?)\)/)[1];//P(p)のpだけを取り出す
                this.glyphname = temp;
                const temp2 = temp.split("-"); //-で分解する
            if(temp2.length <= 1){//これ以上は分割できないとき
                this.name = temp2[0].match(/[A-Za-z]+/g)[0]; 
                this.val = temp2[0].match(/\d+/g)[0];
                return [];
            }
            else{  //分割可能の時、(最後以外)と最後で分割する
                const d_ = temp2.slice(0,-1).join("-");
                return [`${name.split("(")[0]}(${d_}),Pd(${temp2.slice(-1)})`]; //確定でPdなので下ブロックとは違って変数化していない
            }
        }
        else{ //つまりC,Cd,V,Vdの場合
            const temp = name.match(/\((.+?)\)/)[1].split(",");
            this.glyphname = temp.slice(1).join(",");
            this.form = temp[0];
            const temp2 = temp[1].split("-");
                if(temp2.length <= 1){//これ以上は分割できないとき
                    this.name = temp2[0].match(/[A-Za-z]+/g)[0];
                    this.val = temp2[0].match(/\d+/g)[0]; 
                    return []
                }
                else{ //分割可能の時、(最後以外)と最後で分割する
                    const type_ = name.split("(")[0];
                    const type_sep = type_.length == 2 ? type_ : (type_+"d");
                    const d_ = temp2.slice(0,-1).join("-");
                    const d = [`${type_}(${this.form},${d_})`,`${type_sep}(${this.form},${temp2.slice(-1)})`];
                    return d;
                }
            }
        }
    }

    //将来的にget_onset,get_vowel,get_codaはエラー処理をつけようと思う
    #get_vowel(){ return this.type == "S" ? this.childGlyphList[1] : null; }
    #get_onset(){ return this.type == "S" ? this.childGlyphList[0] : null; }
    #get_coda(){ return this.type == "S" ? this.childGlyphList[2] : null;}
    #get_main_glyph(){ return this.type != "S" ? this.childGlyphList[0] : null; }
    #get_diacritical(){ return this.type != "S" ? this.childGlyphList[1] : null; }

    #sub_toPathAbs_Syllable(height,vowelhratio){
        const width = FontManager.getFont(this.font).getTable("FONTDATA").dataList[0].getVal("Thickness");
        const width2 = width*1.;//将来用。1.のところに倍率指定を置く
        const vowel_position = vowelhratio*height
        const vowel_height_half = (this.height_vbottom-this.height_vtop)/2;
        const glyph_height_half = (-this.height_bottom-this.height_top)/2;
        const path = this.toPath();
        switch(this.form){
            case "sol":
                path.toRelativeAll().setDrawPosition(0,vowel_position-vowel_height_half);
                path.toRelativeAll();
                this.gap = {top:0,middle:vowel_position,bottom:height};
            break;
            case "init":
                //高さvbottom~heightを占める棒を挿す
                path.toRelativeAll().setDrawPosition(0,0);
                path.concat(Path.buildSkewer(0,width,width2,this.height_vbottom,height));
                path.toRelativeAll();
                this.gap = {top:0,middle:this.height_vbottom,bottom:height};
            break;
            case "mid":
                //グリフ自体を適切に下にずらした上で
                //高さ0~vowelhratio*height-(vbottom-vowel_positioneight)/2と
                //高さvowelhratio*height+(vbottom-vowel_positioneight)/2~heightとを占める棒を挿す
                path.toRelativeAll().setDrawPosition(0,vowel_position+glyph_height_half-vowel_height_half);
                path.concat(Path.buildSkewer(0,width,width2,vowel_position+glyph_height_half+this.height_vtop,height))
                .concat(Path.buildSkewer(0,width,width2,this.height_vbottom,vowel_position+glyph_height_half-vowel_height_half));
                path.toRelativeAll();
                this.gap = {top:vowel_position+glyph_height_half-vowel_height_half,middle:vowel_position+glyph_height_half-vowel_height_half,bottom:height};
            break;
            case "fin":
                //グリフ自体を適切に下にずらした上で
                //高さheight-(bottom-vowel_height_halfop)を占める棒を挿す
                path.toRelativeAll().setDrawPosition(0,height-(this.height_bottom-this.height_vtop));
                path.concat(Path.buildSkewer(0,width,width,0,height-(this.height_bottom-this.height_vtop)));
                path.toRelativeAll();
                this.gap = {top:0,middle:height-(this.height_bottom-this.height_vtop),bottom:height};
            break;
        }
        return path;
    }
    #sub_toPathAbs_NonSyllable(height,vowelhratio){
        //const width = FontManager.getFont(this.font).getTable("FONTDATA").dataList[0].getVal("Thickness");
        const vowel_position = vowelhratio*height
        const vowel_height_half = (this.height_vbottom-this.height_vtop)/2;
        //const glyph_height_half = (-this.height_bottom-this.height_top)/2;
        const path = this.toPath();
        path.toRelativeAll().setDrawPosition(0,vowel_position-vowel_height_half);
        path.toRelativeAll();
        this.gap = {top:vowel_position-vowel_height_half,middle:vowel_position,bottom:vowel_position+vowel_height_half};
        return path;
    }

    toPathAbsolute(height,vowelhratio){
        return this.type == "S" ? this.#sub_toPathAbs_Syllable(height,vowelhratio) : this.#sub_toPathAbs_NonSyllable(height,vowelhratio);
    }

    #sub_toPathRelative_S_NullVowel(top,bottom){
        const width = FontManager.getFont(this.font).getTable("FONTDATA").dataList[0].getVal("Thickness");
        const width2 = width*1.;//将来用。1.のところに倍率指定を置く
        const path = this.toPath();
         const stick = Path.buildSkewer(0.,width,width2,top+this.height_top,bottom+this.height_bottom);
            switch(this.form){
                case "sol":
                    path.toRelativeAll().setDrawPosition(0.,0.);
                    path.concat(Path.fromPosition(0,bottom+this.height_bottom));
                    path.toRelativeAll().setDrawPosition(0,top+this.height_top);
                break;
                case "init":case "mid":case "fin":
                    path.toRelativeAll().setDrawPosition(0,0).concat(stick);
                break;
            }
        return path;
    }

    #sub_toPathRelative_S_notNullVowel(top,bottom){
        const width = FontManager.getFont(this.font).getTable("FONTDATA").dataList[0].getVal("Thickness");
        const width2 = width*1.;//将来用。1.のところに倍率指定を置く
        const path = this.toPath();
        switch(this.form){
            case "sol":
                path.toRelativeAll().concat(Path.fromPosition(0,bottom+this.height_bottom));
                path.toRelativeAll().setDrawPosition(0,top+this.height_top);
            break;
            case "init":
                path.toRelativeAll().setDrawPosition(0,top);
                path.concat(Path.buildSkewer(0.,width,width2,top+this.height_vbottom,bottom+this.height_bottom));
            break;
            case "mid":
                path.toRelativeAll().setDrawPosition(0,0);
                path.concat(Path.buildSkewer(0.,width,width2,top+this.height_top,this.height_vtop));
                path.concat(Path.buildSkewer(0.,width,width2,this.height_vbottom,bottom+this.height_bottom));
            break;
            case "fin":
                path.toRelativeAll().setDrawPosition(0,0);
                path.concat(Path.buildSkewer(0.,width,width2,top+this.height_top,this.height_vtop));
            break;
            }
        return path;
    }

    #sub_toPathRelative_Syllable(top,bottom){
        const v = this.#get_vowel().glyphname.match(/[A-Za-z]+/g)[0];
        const v_null = FontManager.getStaticTable("VOWEL").getData({Name:v})[0].getVal("isNullVowel");
        return v_null ? this.#sub_toPathRelative_S_NullVowel(top,bottom) : this.#sub_toPathRelative_S_notNullVowel(top,bottom);
    }

    #sub_toPathRelative_NonSyllable(top,bottom){
       const path = this.toPath();
       path.concat(Path.fromPosition(0,bottom+this.height_bottom)).setDrawPosition(0,top+this.height_top);
       return path;
    }

    toPathRelative(top,bottom){
        const path = this.type == "S"? this.#sub_toPathRelative_Syllable(top,bottom) : this.#sub_toPathRelative_NonSyllable(top,bottom);
        path.toRelativeAll();
        this.gap = {top:top,middle:0,bottom:bottom};
        return path;
    }

    #mergeNonSyllable(parent,base, child) {
        const base_ = base.clone();
        const dir = child.type.startsWith("C") ? (child.form === "coda" ? -1 : 1) : 1;
        const off = parent.#calc_offset();
        const child_d = parent.#get_diacritical().path.clone();
        const off_childx = dir*(child_d.getRight()+child_d.getLeft())/2;
        const off_childy = (child_d.getTop()-child_d.getBottom())/2;
        const merged = base_.mergePath2(child_d,off.x+off_childx,off.y+off_childy);
        return merged.toRelativeAll();
    }

    #toPath_NonSyllable() {
        if (this.childGlyphList.length == 0) {
            this.height_vtop = this.path.getTop();
            this.height_vbottom = this.path.getBottom();
            this.height_bottom = this.path.getBottom();
            this.height_top = this.path.getTop();
            return this.path;
        }
        const child = this.#get_main_glyph();
        const base = child.#toPath_NonSyllable();
        const merged = this.#mergeNonSyllable(this,base, child);
        this.path = merged;
        this.height_vtop = this.path.getTop();
        this.height_vbottom = this.path.getBottom();
        this.height_bottom = this.path.getBottom();
        this.height_top = this.path.getTop();
        return merged;
    }


    #toPath_Syllable(){
        let ans = [];
        const c0 = this.#get_onset().#toPath_NonSyllable().clone();
        const v = this.#get_vowel().#toPath_NonSyllable().clone();
        const v_alt = this.#get_vowel().pathOrigin;
        const c1 = this.#get_coda().#toPath_NonSyllable().clone();
        const offs = this.#calc_offset()
        const off0 = offs[0];//this.childGlyphList[0].name_b.glyphname == null ? {x:0,y:0} :this.childGlyphList[0].#calc_offset(v,true);//parentd
        const off1 = offs[1];//this.childGlyphList[2].name_b.glyphname == null ? {x:0,y:0} :this.childGlyphList[2].#calc_offset(v,true);
        const merged = v.mergePath3(c0,c1,0,off0.y,0,off1.y).toRelativeAll();
        this.height_vtop = v_alt.getTop();
        this.height_vbottom = v_alt.getBottom();
        this.height_bottom = merged.getBottom();
        this.height_top = merged.getTop();
        this.path = merged;
        return merged;
    }

    toPath(){//Svgをpathにする
        const path = this.type == "S" ? this.#toPath_Syllable() : this.#toPath_NonSyllable();
        return path ?? Path.fromPosition(0,0); //一応ヌル対策として最悪はM 0,0を返す。
    }

    #calc_offset_NonSyllable(){
        if(this.childGlyphList.length < 1) return {x:0,y:0};
            const parentd = this.#get_main_glyph().path;
            const off1 = this.#get_diacritical().offset;
            const alig1 = this.#get_diacritical().aligment;
             if(this.type.startsWith("C")){
                const dir_ = {onset:1,coda:-1};
                const dir = dir_[this.form];
                const x =  (parentd.getLeft()*(1-alig1.x*dir)/2+parentd.getRight() *(1+alig1.x*dir)/2)+off1.x*dir;
                const y =  (parentd.getTop()*(1-alig1.y)/2+parentd.getBottom() *(1+alig1.y)/2)+off1.y;
                return{x:x,y:y};
            } else{
                const x =  (parentd.getLeft()*alig1.x/2+parentd.getRight()*-alig1.x/2)+off1.x;
                const y =  (parentd.getTop()*(1-alig1.y)/2+parentd.getBottom() *(1+alig1.y)/2)+off1.y;
                return{x:x,y:y};
            }
    }

    #calc_offset_S_NullVowel(){
        const c_len = this.childGlyphList.length;
        const c0offset = c_len > 0 ? this.#get_onset().offset : {x:0,y:0};
        const c2offset = c_len > 2 ? this.#get_coda().offset : {x:0,y:0};
        const c0d = c_len > 0 ? this.#get_onset().path : new Path();
        const c1d = this.#get_vowel().path;
        const c2d = c_len > 2 ? this.#get_coda().path : new Path();
        const topgap = Math.min(c0d.getTop(),c2d.getTop());
        const bottomgap = Math.max(c0d.getBottom(),c2d.getBottom());
        return [{x:c0offset.x,y:c1d.getBottom()+topgap-bottomgap+c0offset.y},{x:c2offset.x,y:c1d.getBottom()+topgap-bottomgap+c2offset.y}];
    }

    #calc_offset_S_notNullVowel(){
        const c_len = this.childGlyphList.length;
        const c0offset = c_len > 0 ? this.#get_onset().offset : {x:0,y:0};
        const c2offset = c_len > 2 ? this.#get_coda().offset : {x:0,y:0};
        const c0d = c_len > 0 ? this.#get_onset().path : new Path();
        const c1d = this.#get_vowel().path;
        const c2d = c_len > 2 ? this.#get_coda().path : new Path();
        const topgap = Math.min(c0d.getTop(),c2d.getTop());
        const bottomgap = Math.max(c0d.getBottom(),c2d.getBottom());
        switch(this.form){
            case "init":
                return [{x:c0offset.x,y:c1d.getBottom()+topgap+c0offset.y},{x:c2offset.x,y:c1d.getBottom()+topgap+c2offset.y}];
            case "mid":
            case "sol":
                return [{x:c0offset.x,y:c1d.getTop()-c0d.getBottom()+c0offset.y},{x:c2offset.x,y:c1d.getBottom()+c2d.getTop()+c2offset.y}];
            case "fin":
                return [{x:c0offset.x,y:c1d.getTop()-bottomgap+c0offset.y},{x:c2offset.x,y:c1d.getTop()-bottomgap+c2offset.y}];
    }
    }

    #calc_offset_Syllable(){
        const v = this.#get_vowel().glyphname.match(/[A-Za-z]+/g)[0];
        const v_null = FontManager.getStaticTable("VOWEL").getData({Name:v})[0].getVal("isNullVowel");
        return v_null ? this.#calc_offset_S_NullVowel() : this.#calc_offset_S_notNullVowel();
    }

    #calc_offset(){
        return this.type == "S" ? this.#calc_offset_Syllable() : this.#calc_offset_NonSyllable();
    }
}


export {Glyph,GlyphArray};
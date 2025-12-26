//import { FontManager } from "./deps.js";


class DataTable {
  constructor(dt,parent) {
    this.parent = parent;
    this.name = dt.name;
    this.fontname = "";
    this.columnList = []; //{name:"",type:"",desc:"",order:0,subtype : ""}
    this.dataList = [];
    this.desc = ""; //データの説明
    this.load(dt)
  }
  load(dt){
    const COLUMN = dt.columnList;
    const DATA = dt.data;
    for(const cn in COLUMN){
      const c = COLUMN[cn];
      const k = {name:c.name,type:c.type,desc:c.desc,order:c.order,subtype:c.subtype,dev:c.dev};
      this.columnList.push(k);
    }
    for(const dn in DATA){
      const d = new Data(this);
      for(const k in DATA[dn]){
        const type = dt.columnList[k].type;let tmp = DATA[dn][k];
        if(type == "char"){tmp = tmp.toString()}
        else if(type == "bool"){tmp = typeof tmp == "boolean" ? tmp : tmp=="true"}
        else{tmp = Number(tmp);}
        DATA[dn][k] = tmp;
      }
      d.valueList = DATA[dn];
      this.dataList.push(d);
    }
  }
  static isavailableType(str) {
    return ["char","float","INTEGER","bool"].includes(str);
  }
  getColumn(name,debug) {
    debug ??= false;
    try {
      for (const i in this.columnList) {
        if (this.columnList[i]["name"] == name) return this.columnList[i];
      }
      if(debug)throw new Error(`${name}は存在しません`);else return null;
    } catch (e) {
      throw e;
    }
  }
  createColumn(name,type,desc,priorty,val_init) {
    //val_initは未使用 一応後付で作るかも
    try {
      const errmessage = [];
      for (const i in this.columnList) {
        if (this.columnList[i]["name"] == name) {
          errmessage.push(`${name}は既に存在します`);
        }
      }
      if (DataTable.isavailableType(type) == false) { //そんな型指定できない時の処理
        errmessage.push(`${type}という型は指定できません`);
      }
      else if(val_init == null){ //空だったら
          const val_ = {INTEGER:1,float:0.0,bool:false,char:""};
          val_init = val_[type];
        }
        else{ //なんか入ってた場合。
          const val_ = {INTEGER:"number",float:"number",bool:"boolean",char:"string"};
          const val2_ = typeof val_init;
          if(val2_ != val_[type]){errmessage.push(`${type}"型として${val_init}は初期値に指定できません`);}
          }
      if (errmessage.length != 0) throw new Error(errmessage.join("\n"));
      
      this.columnList.push({ name: name, type: type ,desc : desc,priorty : priorty,dev:false});
      for (let i = 0; i < this.dataList.length; i++) {
        this.dataList[i].valueList[name] = val_init;
      }
    } catch (e) {
      throw e;
    }
  }

  deleteColumn(name) { //使うな
    try {
      const errmessage = [];
      const deletion = this.getColumn(name);
      if (!deletion) errmessage.push(`${name}というColumnは存在しません`);
      if (errmessage.length != 0) throw new Error(errmessage.join("\n"));

      const index = this.columnList.indexOf(deletion);
      this.columnList.splice(index, 1);
      for (let i = 0; i < this.dataList.length; i++) {
        delete this.dataList[i].valueList[name];
      }
    } catch (e) {
      throw e;
    }
  }
  rewriteColumn(name, name_new,genre) { //あんま使う機会ない
    try {
      genre ??= "name";
      const errmessage = [];
      const subject = this.getColumn(name);
      if (subject == null) { //そんなものがない時の処理
        errmessage.push(`${name}というColumnは存在しません`);
      }
      if (genre == "name"&& this.getColumn(name_new) != null) { //既にそれがある場合の処理
        errmessage.push(`${name_new}というColumnは既に存在します`);
      }
      if(["name","type","desc","order","subtype"].includes(genre)) errmessage.push(`${genre}というパロメータは存在しません`);
      if (errmessage.length != 0) throw new Error(errmessage.join("\n"));

      if (subject != null) subject[genre] = name_new;
      if(genre == "name"){
      for (const i in this.dataList) {
        const newdata = this.dataList[i].valueList[name];
        this.dataList[i].valueList[name_new] = newdata;
        delete this.dataList[i].valueList[name];
        }
      }
    } catch (e) {
      throw e;
    }
  }

  getData(param_reg) { //param_regは{Name://,...}って感じ
    const errorcol = [];
    try {
      for (const col in param_reg) {
        if (this.getColumn(col) == null) errorcol.push(col);
      }
      if (errorcol.length != 0) {
        const errmessage = `${this.name}に以下のcolumnは存在しません: ${errorcol}`;
        throw new Error(errmessage);
      }
      const ans = [];
      skip: for (const i of this.dataList) {
        for (const col in param_reg) {
          const val_ = i.getVal(col);
          const p_ = param_reg[col];
          if (p_ instanceof RegExp){if(!p_.exec(val_.toString())) continue skip;}
          else{if( p_ != val_) continue skip;} 
        }
        ans.push(i);
      }
      return ans;
    } catch (e) {
      throw e;
    }
  }

  getLeastAvailableID(){
    const IDs = this.dataList.map((i) => (i.valueList.ID));
    IDs.sort((a,b) => (a-b));
    let last = -1;
    for(let i=0;i<IDs.length;i++){
      if(IDs[i]-last > 1) return last+1;
      else last++;
    }
    return Math.max(last+1,0);
  }

  createData(param) { //paramは{Name:"",...}って感じ。IDは不要（自動で付与します）
    const errmessage = [];
    const errorcol = [];
    const ID_ = this.getLeastAvailableID();
    param.ID =ID_;
    try {
      skip: for (const col of this.columnList) {
        for (const p in param) if (col.name == p) continue skip;
        errorcol.push(col.name);
      }
      if (errorcol.length != 0) errmessage.push(`以下のcolumnが不足しています: ${errorcol}`);
      if (errmessage.length != 0) throw new Error(errmessage.join("\n"));

      const creation = new Data(this);
      creation.valueList = param;
      this.dataList.push(creation);
    } catch (e) {
      throw e;
    }
  }
  //delMAXに負の値を指定してください
  deleteData(param_reg,delMAX) 
  { //param_regは{Name://,...}って感じ
    delMAX ??= 1;
    const errmessage = [];
    const deletionList = this.getData(param_reg);
    try {
      if (delMAX >= 0 && deletionList.length > delMAX) errmessage.push(`指定された最大削除可能数(${delMAX})を超えています(初期値:1)`);
      if (errmessage.length != 0) throw new Error(errmessage.join("\n"));

      deletionList.forEach((i) => this.dataList.splice(this.dataList.indexOf(i), 1));
    } catch (e) {
      throw e;
    }

    return deletionList; //削除したデータ数を返す？
  }
  rewriteData(param_reg,param,reMAX) { 
    //param_regは{Name://,...}って感じ
    reMAX ??= 1;
    //干渉したデータ数を返す？
    const errmessage = []
    try {
      const subjectList = this.getData(param_reg);
      if (reMAX >= 0 && subjectList.length > reMAX) errmessage.push(`指定された最大削除可能数(${reMAX})を超えています(初期値:1)`);
      if (errmessage.length != 0) throw new Error(errmessage.join("\n"));

      subjectList.forEach((i) => {for (const p in param) i.valueList[p] = param[p];})
      return subjectList;
    } catch (e) {
      throw e;
    }
  }
}

export default class Data {
    constructor(parent) {
    this.parent = parent;
    this.valueList = {}; //{name:"",val:""}
  }
  getVal(param){return this.valueList[param];}
}

export {DataTable,Data}
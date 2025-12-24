import { FontManager, RegExp_Khhyl } from "../deps.js"; // ,DataTable,Data

class Parser {
  //Paramは単にstringかRegExp
  static getParser(param) {
    if (param instanceof RegExp) param = { Name: param };
    if (typeof param == "string") param = { Name: param };

    const table_ = FontManager.getStaticTable("Parser");
    return table_.getData(param);
  }
  static rewriteParser(param, param2) {
    if (param instanceof RegExp) param = { Name: param };
    if (typeof param == "string") param = { Name: param };

    if (typeof param2 == "string") param2 = { Name: param2 };
    const table_ = FontManager.getStaticTable("Parser");

    const Parser_a = Parser.getParser(param.Name);
    const Parser_b = Parser.getParser(param2.Name);
    if (param.Name != null && Parser_a.length >= 2 && param2.Name != null) {
      throw new Error("変更後に重複が発生します");
    }
    if (param2.Name != null && Parser_b.length != 0) {
      throw new Error("変更後に重複が発生します");
    }

    return table_.rewriteData(param, param2, -1);
  }
  static deleteParser(param, safety) {
    safety ??= true;
    if (param instanceof RegExp) param = { Name: param };
    if (typeof param == "string") param = { Name: param };

    if (safety && Parser.getParser(param).length > 1) {
      return new Error(
        "削除対象が2つ以上あります。まとめて削除したい場合はsafetyをfalseに指定してください",
      );
    }
    const table_ = FontManager.getStaticTable("Parser");
    return table_.deleteData(param, 1);
  }
  static createParser(param) {
    if (Parser.getParser(param)) {
      return new Error(`${param}はすでに存在しています`);
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
    const table_ = FontManager.getStaticTable("Parser");
    table_.createData(param);
  }
  static setParserColumnAll() {
    Parser.setParserColumn();
  }
  static setParserColumn(id) {
    const table_ = FontManager.getStaticTable("PARSER");
    const ParserData = id == null
      ? table_.dataList
      : table_.getData({ ID: id });

    try {
      ParserData.forEach((i) => {
        const r_ = new RegExp_Khhyl(i.getVal("Name"), {}).ParseRegExp()
          .toNormalRegExp();
        table_.rewriteData({ ID: i.getVal("ID") }, { Parsed: r_ });
      });
    } catch (e) {
      return new Error(e.message);
    }
  }
  static parse(raw, type) {
    const table_ = FontManager.getStaticTable("PARSER");
    const r_ = raw.split("");
    let raw_new = "";
    r_.forEach((r) => raw_new += `R(${r})`);
    const array = table_.getData({ Pattern: (type == 0 ? /(u|c)/ : /(u|o)/) });
    const sortalg = function (first, second) { //Priorityの小さい順に並び替える
      const l_ = Math.sign(first.getVal("Order") - second.getVal("Order"));
      return l_ != 0
        ? l_
        : Math.sign(first.getVal("Priority") - second.getVal("Priority"));
    };
    array.sort(sortalg);
    array.forEach((i) => {
      raw_new = raw_new.replaceAll(
        new RegExp(i.getVal("Parsed"), "g"),
        i.getVal("NameAlt"),
      );
    });

    return raw_new;
  }
}

export { Parser };

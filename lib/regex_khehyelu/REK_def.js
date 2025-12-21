import { LetterManager, RegExp_Khhyl } from "../deps.js";
import { REK_cond } from "./REK_cond.js";
class REK_def {
  /*
  reg_khhyl,ans,reg_string,msgは
  基本的に
  reg_khhyl:regexp_khhyl本体
  ans:結果を格納する配列
  reg_string:regex_string部分
  msg:マッチした文字列
  */
  static rule_form = {
    ["\\*"]: (reg_khhyl, ans, reg_string, msg) => {
      if (reg_khhyl.intent.subtype == "V") {
        return REK_def.PREsub_lower(
          reg_khhyl,
          ans,
          reg_string,
          "(?:init|mid|fin|sol|null)",
          msg,
          "form",
        );
      }
      return REK_def.PREsub_lower(
        reg_khhyl,
        ans,
        reg_string,
        "(?:onset|coda|null)",
        msg,
        "form",
      );
    },
    // |記号、または(*+?)? があったら
    ["(\\\||(\\\*|\\\+|\\\?)\\\??)"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    }, //()の類
    ["\\\((\\\?(<.*?>)?:)?"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_br_A(reg_khhyl, ans, reg_string, msg);
    }, //文字
    ["[A-Za-z]+"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    [" "]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, "", msg);
    },
  };

  static rule_script = {
    [".+"]: //[]
      (reg_khhyl, ans, reg_string, msg) => {
        const hensuu = [];
        const table = {
          "V": "VOWEL",
          "C": "CONSONANT",
          "P": "PUNCTUATION",
          "Vd": "DIACRITIC_V",
          "Cd": "DIACRITIC_C",
          "Pd": "DIACRITIC_P",
        };
        const str = reg_khhyl.intent.subtype;
        let AL;
        if (typeof str == "string") {
          AL = LetterManager.getLetter({ Name: /(|.*)/g });
        }
        if (AL == null || AL instanceof Error) throw AL;
        for (const a_ of AL) {
          if (table[str] != a_.parent.name) continue;
          const val2 = REK_cond.pc(a_, msg);
          if (val2 === true) {
            hensuu.push(a_.getVal("Name").toString());
          }
        }
        const letter = (hensuu.length != 0) ? hensuu.join("|") : "（無し）";
        //if(letter == "") letter = "（無し）";
        return REK_def.PREsub_lower(
          reg_khhyl,
          ans,
          reg_string,
          letter,
          msg,
          "g",
        );
      },
  };
  static rule_g = {
    ["(\\\||(\\\*|\\\+|\\\?)\\\??)"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    // [(条件の羅列)]
    ["\\["]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_br_D(reg_khhyl, ans, reg_string, msg, "script");
    },
    ["\\."]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, "[A-Za-z]+", msg);
    },
    ["（無し）"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    ["_"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, "\\d+", msg);
    },
    ["[A-Za-z]+"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    ["\\d+"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    ["\\(\\\?<?[=!]"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_br_B(reg_khhyl, ans, reg_string, msg);
    },
    ["\\((\\\?(<.*?>)?:)?"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_br_A(reg_khhyl, ans, reg_string, msg);
    },
    ["{\\\d+(,|,\\\d+)?}"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_kazu(reg_khhyl, ans, reg_string, msg);
    },
    [" "]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, "", msg);
    },
  };

  static rule_G = {
    ["-\\*"]: (reg_khhyl, ans, reg_string, msg) => {
      reg_khhyl.intent.isFirst = "TRUE";
      return REK_def.PREsub_lower(
        reg_khhyl,
        ans,
        reg_string,
        "(?:|-._(?:-._)*)",
        msg,
        "G",
      );
    },
    ["-\\+"]: (reg_khhyl, ans, reg_string, msg) => {
      reg_khhyl.intent.isFirst = "TRUE";
      return REK_def.PREsub_lower(
        reg_khhyl,
        ans,
        reg_string,
        "(?:|-._(?:-._)*)",
        msg,
        "G",
      );
    },
    ["-\\?"]: (reg_khhyl, ans, reg_string, msg) => {
      reg_khhyl.intent.isFirst = "TRUE";
      return REK_def.PREsub_lower(
        reg_khhyl,
        ans,
        reg_string,
        "(?:|-._?)",
        msg,
        "G",
      );
    },
    ["\\*"]: (reg_khhyl, ans, reg_string, msg) => {
      if (reg_khhyl.intent.isFirst == "FALSE") {
        return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
      }
      return REK_def.PREsub_lower(
        reg_khhyl,
        ans,
        reg_string,
        "(?:|._(?:-._)*)",
        msg,
        "G",
      );
    },
    ["\\+"]: (reg_khhyl, ans, reg_string, msg) => {
      if (reg_khhyl.intent.isFirst == "FALSE") {
        return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
      }
      return REK_def.PREsub_lower(
        reg_khhyl,
        ans,
        reg_string,
        "._(?:-._)*",
        msg,
        "G",
      );
    },
    ["\\?"]: (reg_khhyl, ans, reg_string, msg) => {
      if (reg_khhyl.intent.isFirst == "FALSE") {
        return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
      }
      return REK_def.PREsub_lower(
        reg_khhyl,
        ans,
        reg_string,
        "(?:._)?",
        msg,
        "G",
      );
    },
    ["(\\\||(\\\*|\\\+|\\\?)\\\??)"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    ["(\\[.+?\\]|[A-Za-z]|\\d+|_|\\.)+"]: (reg_khhyl, ans, reg_string, msg) => {
      reg_khhyl.intent.isFirst = "FALSE";
      return REK_def.PREsub_lower(reg_khhyl, ans, reg_string, msg, msg, "g");
    },
    ["-"]: (reg_khhyl, ans, reg_string, msg) => {
      reg_khhyl.intent.isFirst = "TRUE";
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    ["\\\(\\\?<?[=!]"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_br_B(reg_khhyl, ans, reg_string, msg);
    },
    ["\\\((\\\?(<.*?>)?:)?"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_br_A(reg_khhyl, ans, reg_string, msg);
    },
    ["{\\\d+(,|,\\\d+)?}"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_kazu(reg_khhyl, ans, reg_string, msg);
    },
    [" "]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, "", msg);
    },
  };

  static rule_r = {
    [".+"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
  };

  static rule_scvpd = {
    [".*?,.*?,.*?,.*"]: (reg_khhyl, ans, reg_string, msg) => {
      const seperated = msg.split(",");
      const type = ["form", "G", "G", "G"];
      const subtype = ["V", "C", "V", "C"];
      const typeB = reg_khhyl.intent.type;
      if (seperated != null && seperated.length == 4 && typeB == "S") {
        for (let i = 0; i < seperated.length; i++) {
          const intent_after = { ...reg_khhyl.intent };
          intent_after.type = type[i];
          intent_after.isFirst = "TRUE";
          intent_after.subtype = subtype[i];
          intent_after.subtypeb = "none";
          const t = new RegExp_Khhyl(seperated[i], intent_after);
          ans.push(t);
        }
        reg_string = reg_string.slice(msg.length + 1);
        return [ans, reg_string];
      }
      throw Error(`${reg_khhyl.intent.type}(${msg})は不正な正規表現です`);
    },
    [".*?,.*"]: (reg_khhyl, ans, reg_string, msg) => {
      const seperated = msg.split(",");
      const typeB = reg_khhyl.intent.type;

      if (seperated != null && seperated.length == 2) {
        if (typeB == "S") {
          const type = ["form", "G", "G", "G"];
          const subtype = ["V", "C", "V", "C"];
          const sep2 = seperated.concat("*", "*");
          for (let i = 0; i < sep2.length; i++) {
            const intent_after = { ...reg_khhyl.intent };
            intent_after.type = type[i];
            intent_after.isFirst = "TRUE";
            intent_after.subtype = subtype[i];
            intent_after.subtypeb = "none";
            const t = new RegExp_Khhyl(sep2[i], intent_after);
            ans.push(t);
          }
          reg_string = reg_string.slice(msg.length + 1);
          return [ans, reg_string];
        } else if (typeB == "X") {
          const condition = seperated != null && seperated.length == 1;
          return condition
            ? REK_def.PREsub_END(reg_khhyl, ans, reg_string, seperated[0], msg)
            : [];
        } else if (["V", "Vd", "C", "Cd"].includes(typeB)) {
          for (let i = 0; i < seperated.length; i++) {
            const intent_after = { ...reg_khhyl.intent };
            const type = ["form", "G"];
            intent_after.type = type[i];
            intent_after.isFirst = "TRUE";
            intent_after.subtype = typeB;
            intent_after.subtypeb = "none";
            const t = new RegExp_Khhyl(seperated[i], intent_after);
            ans.push(t);
          }
          reg_string = reg_string.slice(msg.length + 1);
          return [ans, reg_string];
        }
      }
      throw Error(`${reg_khhyl.intent.type}(${msg})は不正な正規表現です`);
    },
    [".+"]: (reg_khhyl, ans, reg_string, msg) => {
      const seperated = msg.split(",");
      const typeB = reg_khhyl.intent.type;
      if (seperated != null && seperated.length == 1) {
        if (typeB == "S") {
          const type = ["form", "G", "G", "G"];
          const subtype = ["V", "C", "V", "C"];
          const sep2 = seperated.concat("*", "*", "*");
          for (let i = 0; i < sep2.length; i++) {
            const intent_after = { ...reg_khhyl.intent };
            intent_after.type = type[i];
            intent_after.isFirst = "TRUE";
            intent_after.subtype = subtype[i];
            intent_after.subtypeb = "none";
            const t = new RegExp_Khhyl(sep2[i], intent_after);
            ans.push(t);
          }
          reg_string = reg_string.slice(msg.length + 1);
          return [ans, reg_string];
        } else if (["C", "Cd", "V", "Vd"].includes(typeB)) {
          const type = ["form", "G"];
          const sep2 = seperated.concat("*");
          for (let i = 0; i < sep2.length; i++) {
            const intent_after = { ...reg_khhyl.intent };
            intent_after.type = type[i];
            intent_after.isFirst = "TRUE";
            intent_after.subtype = typeB;
            intent_after.subtypeb = "none";
            const t = new RegExp_Khhyl(sep2[i], intent_after);
            ans.push(t);
          }
          reg_string = reg_string.slice(msg.length + 1);
          return [ans, reg_string];
        } else if (["P", "Pd"].includes(typeB)) {
          const intent_after = { ...reg_khhyl.intent };
          intent_after.type = "G";
          intent_after.isFirst = "TRUE";
          intent_after.subtype = typeB;
          intent_after.subtypeb = "none";
          const t = new RegExp_Khhyl(seperated[0], intent_after);
          ans.push(t);
          reg_string = reg_string.slice(msg.length + 1);
          return [ans, reg_string];
        }
      }
      throw Error(`${reg_khhyl.intent.type}(${msg})は不正な正規表現です`);
    },
  };

  static rule_l = {
    ["L"]: (reg_khhyl, ans, reg_string, _msg) => {
      const hensuu = [
        ["*,*", "C"],
        ["*,*", "V"],
        ["*,*", "Cd"],
        ["*,*", "Vd"],
        ["*", "P"],
        ["*", "Pd"],
        ["*,*,*,*", "S"],
      ];
      const letter = hensuu.map((i) => `${i[1]}(${i[0]})`).join("|");
      return REK_def.PREsub_lower(reg_khhyl, ans, reg_string, letter, _msg, "");
    },
  };
  static rule_SEN = {
    ["\\\^"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    ["\\\$"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    ["(\\\||(\\\*|\\\+|\\\?)\\\??)"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, msg, msg);
    },
    ["Null\\(\\)"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, "Null\(\\)", msg);
    },
    ["Sep\\(\\)"]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, "Sep\\(\\)", msg);
    },
    ["L\\(\\)"]: //PREsub_br_Cを用いる。
      (reg_khhyl, ans, reg_string, msg) => {
        return REK_def.PREsub_lower(reg_khhyl, ans, reg_string, "L", msg, "L");
      },
    ["(R|X|S|[CVP]d?)\\("]: //PREsub_br_Cを用いる。
      (reg_khhyl, ans, reg_string, msg) => {
        const type = msg.match(/^L|R|X|S|[CVP]d?/g);
        if (type != null) {
          return REK_def.PREsub_br_C(reg_khhyl, ans, reg_string, msg, type[0]);
        } else throw Error(`不正な値です：${msg}`);
      },
    ["\\\(\\\?<?[=!]"]: (reg_khhyl, ans, reg_string, msg) => { // (?<=y)、(?=y) (?!y) (?<!y)
      return REK_def.PREsub_br_B(reg_khhyl, ans, reg_string, msg);
    },
    ["\\\((\\\?(<.*?>)?:)?"]: (reg_khhyl, ans, reg_string, msg) => { // () (?:),(?<name>),(?P<name>)
      return REK_def.PREsub_br_A(reg_khhyl, ans, reg_string, msg);
    },
    ["{\\\d+(,|,\\\d+)?}"]: (reg_khhyl, ans, reg_string, msg) => { //{n} {n,} {n,m}
      return REK_def.PREsub_kazu(reg_khhyl, ans, reg_string, msg);
    },
    [" "]: (reg_khhyl, ans, reg_string, msg) => {
      return REK_def.PREsub_END(reg_khhyl, ans, reg_string, "", msg);
    },
  };
  //reg_khhyl,ans,reg_string,何という文字列に変換するか,msg
  static PREsub_END(reg_khhyl, ans, reg_string, letter, msg) {
    const intent_after = { ...reg_khhyl.intent };
    intent_after.type = "FINITE";
    intent_after.isend = "TRUE";
    intent_after.subtypeb = "none";
    const t = new RegExp_Khhyl(letter, intent_after);
    ans.push(t);
    reg_string = reg_string.slice(msg.length);
    return [ans, reg_string];
  }
  //reg_khhyl,ans,reg_string,何という文字列に変換するか,msg,type(次の階層)
  static PREsub_lower(reg_khhyl, ans, reg_string, letter, msg, type) {
    const intent_after = { ...reg_khhyl.intent };
    intent_after.type = type;
    intent_after.subtypeb = "none";
    if (reg_khhyl.intent.type == type && type == "G") {
      intent_after.isoutofBrancket = false;
    }
    const t = new RegExp_Khhyl(letter, intent_after);
    ans.push(t);
    reg_string = reg_string.slice(msg.length);
    return [ans, reg_string];
  }
  //[] とか。
  static PREsub_br_D(reg_khhyl, ans, reg_string, letter, type) {
    const intent_after = { ...reg_khhyl.intent };
    let i = 1;
    let j = 1;
    for (i = letter.length; i < reg_string.length; i++) {
      if (reg_string[i] == "[") j++;
      else if (reg_string[i] == "]") j--;
      if (j == 0) break;
    }
    if (j != 0) {
      throw Error(
        `${reg_string}([任意の文字列])のような括弧類が閉じていません`,
      );
    }
    intent_after.type = type;
    intent_after.subtypeb = "[]";
    intent_after.isoutofBrancket = false;
    const t = new RegExp_Khhyl(
      reg_string.slice(letter.length, i),
      intent_after,
    );
    ans.push(t);
    reg_string = reg_string.slice(i + 1);
    return [ans, reg_string];
  }
  //()類 lowerと同じ引数 「S()」とか「L()」みたいなやつ
  static PREsub_br_C(reg_khhyl, ans, reg_string, letter, type) {
    const intent_after = { ...reg_khhyl.intent };
    let i = 1; //カッコの閉じる場所
    let j = 1;
    for (i = letter.length; i < reg_string.length; i++) {
      if (reg_string[i] == "(") j++;
      else if (reg_string[i] == ")") j--;
      if (j == 0) break;
    }
    if (j != 0) throw Error(`${type}(...) が不正です`);
    intent_after.type = type;
    intent_after.subtypeb = "none";
    const t = new RegExp_Khhyl(
      reg_string.slice(letter.length, i),
      intent_after,
    );
    ans.push(t);
    reg_string = reg_string.slice(i + 1);
    return [ans, reg_string];
  }
  //前方の(?<=y) (?<!y)と後方の(?=y) (?!y)
  static PREsub_br_B(reg_khhyl, ans, reg_string, letter) {
    const intent_after = { ...reg_khhyl.intent };
    let i = 1;
    let j = 1;
    for (i = 1; i < reg_string.length; i++) {
      if (reg_string[i] == "(") j++;
      else if (reg_string[i] == ")") j--;
      if (j == 0) break;
    }
    if (j != 0) throw Error("(?<=y)、(?=y)のような括弧類が閉じていません");
    intent_after.isoutofBrancket = false;
    intent_after.subtypeb = letter + "y)";
    const t = new RegExp_Khhyl(
      reg_string.slice(letter.length, i),
      intent_after,
    );
    ans.push(t);
    reg_string = reg_string.slice(i + 1);
    return [ans, reg_string];
  }
  //()
  static PREsub_br_A(reg_khhyl, ans, reg_string, letter) {
    const intent_after = { ...reg_khhyl.intent };
    const br_start = letter.length;
    let i = 1; // br_end
    let j = 1; //
    for (i = 1; i < reg_string.length; i++) {
      if (reg_string[i] == "(") j++;
      else if (reg_string[i] == ")") j--;
      if (j == 0) break;
    }
    if (j != 0) {
      throw Error(
        `${reg_string}(<任意の文字列>)のような括弧類が閉じていません`,
      );
    }
    intent_after.isoutofBrancket = false;
    intent_after.subtypeb = reg_string.slice(0, br_start) + ")";
    const t = new RegExp_Khhyl(reg_string.slice(br_start, i), intent_after);
    ans.push(t);
    reg_string = reg_string.slice(i + 1);
    return [ans, reg_string];
  }
  //{}
  static PREsub_kazu(reg_khhyl, ans, reg_string, letter) {
    const intent_after = { ...reg_khhyl.intent };
    intent_after.type = "{n}";
    intent_after.subtype2 = "none";
    intent_after.subtype = "{n}";
    let b = reg_string.match(/{\d+,\d+}/);
    if (b != null) intent_after.subtype = "{n,m}";
    else {
      b = reg_string.match(/{\d+,}/);
      if (b != null) intent_after.subtype = "{n,}";
      else {if (reg_string.match(/{\d+}/) == null) {
          throw Error("{n(,m)}の中が不正です");
        }}
    }
    const t = new RegExp_Khhyl(letter, intent_after);
    ans.push(t);
    reg_string = reg_string.slice(letter.length);
    return [ans, reg_string];
  }
}
export { REK_def };

import { REK_def } from "./REK_def.js";
/*lex+yacc的なことでもする？

        開始^
        終了$

        囲い(前) ( (?: (?<[A-Za-z]+>
        囲い(後) )

        前b(?<=y)(?<!y)
        後 * + ?  {0|[1-9][0-9]} {0|[1-9][0-9],} {0|[1-9][0-9],0|[1-9][0-9]}
           *? +? ??  {0|[1-9][0-9]}? {0|[1-9][0-9],}? {0|[1-9][0-9],0|[1-9][0-9]}?
        後b(?=y) (?!=y)
        分割 |

        特殊文字 \\0|[1-9][0-9] \\k<[A-Za-z]+>



        括弧okって時
        x := (?: ( | \(\?: | \(<.*?> ) x)

        前b okって時
        x := \(\?<!|= x\) x

        後okってとき
        x := x(\* | \+ | \? | {n} | {n,} | {n,m})\?

        後b okって時
        x := x \( \?!|= x\)

        分割 okって時
        x := x | x

        キャプチャokって時
        x := \[1-9][0-9]* \k<.*?>


    使用可能な文字
    n0 := [A-Za-z]+
    n1 := [<letterの情報に基づいたcond文>]
    n := n0|n1
    v := 0|[1-9][0-9]*

    字母の定義

    ↑一旦トークナイズする。理解不能文が一周したらエラーを返す

    g := nv
      := n.
      := _v
      := .
    ↑解釈不能な場合は一旦gに移す
    g_sub := g
          := +  .(-.)* に変換。
          := *  (空|.(-.)*) に変換
    ↑解釈不能な場合は一旦g_subに移す
    G := g_sub(-g_sub)*


    取りうる形状の定義
    form_v := (init|mid|fin|sol)
    form_c := (onset|coda)

    音節の定義
    S := S\(form_v,G?,G?,G?\)
           S\(form_v,\*\)
           S\(\*\)

    単独字母の定義
    C := C\(form_c,G\)
    Cd := Cd(form_c,G\)

    V := V\(form_v,G\)
    Vd := Vd\(form_v,G\)

    P := P\(G\)
    Pd := Pd\(G\)

    X := X\(.*,"type"\) 東果世界に存在する東果文字以外の文字（未実装）
    R := R\(*\) 現実世界の文字


    東果文字の全部。「.」的な
    L := L\(\)

    あらゆる文字。
    L_ALL := Lx\(\)

*/

class RegExp_Khhyl {
    constructor(regex_string, intent) {
        this.regex_string = regex_string;
        this.intent = intent; //基本的には指定する
        this.child = [];
    }
    //Tokenize -> Parse -> Tokenize（変更点が無くなるまで繰り返す）
    toNormalRegExp() {
        let parsed_regex = "";
        for (let i = 0; i < this.child.length; i++) {
            parsed_regex += this.child[i].toNormalRegExp();
            parsed_regex +=
                (this.intent.type.match(/[SRX]|[CVP]d?/g) != null) &&
                    (i != this.child.length - 1)
                    ? ","
                    : "";
        }
        parsed_regex += this.regex_string;
        switch (this.intent.type) {
            case "R":
            case "X":
            case "C":
            case "Cd":
            case "V":
            case "Vd":
            case "P":
            case "Pd":
            case "S":
                parsed_regex = `${this.intent.type}\\(${parsed_regex}\\)`;
                //parsed_regex = `${this.intent.type}\\(\\?<${this.intent.type}>${parsed_regex}\\)`;
                // 例えば、S(parsed_regex)に対して、S\\((?\k<S0>parsed_regex)\\)のようにするのは
                // 要素が『（）』の中にない場合に判定したい
                // S(*,s0-d0,a0,)のd0は $k<S0G0g1>のように取得
                //                 dなら$K<S0G0g1_n>
                break;
        }
        //if(parentlist.length != 0) parsed_regex = `(?<${parentlist.join("")}>${parsed_regex})`;

        if ((this.intent.subtypeb ?? "").match(/^\(/) != null) {
            parsed_regex = `${
                this.intent.subtypeb.slice(0, -1)
            }${parsed_regex})`;
        } else if ((this.intent.subtypeb ?? "").match(/^\[/) != null) {
            parsed_regex = `(?:${parsed_regex})`;
        }
        return parsed_regex;
    }

    ParseRegExp() {
        this.intent.type ??= "";
        this.intent.isoutofBrancket ??= true;
        const rule = [];
        switch (this.intent.type) {
            case "":
                rule.push("rule_SEN");
                break;
            case "L":
                rule.push("rule_l");
                break;
            case "form":
                rule.push("rule_form");
                break;
            case "R":
                rule.push("rule_r");
                break;
            case "X":
            case "S":
            case "C":
            case "Cd":
            case "V":
            case "Vd":
            case "P":
            case "Pd":
                rule.push("rule_scvpd");
                break;
            case "G":
                rule.push("rule_G");
                break;
            case "g":
                rule.push("rule_g");
                break;
            case "script":
                rule.push("rule_script");
                break;
        }
        if (rule.length != 0) {
            const k = this.ParseRegExp_sub(REK_def[rule[0]]);
            if (k instanceof Error) throw k;
            this.child = k;
            for (const i of this.child) {
                const k = i.ParseRegExp();
                if (k instanceof Error) throw k;
            }
        }
        return this;
    }
    ParseRegExp_sub(rules) {
        let parsed_regex = [];
        let count = 10000;
        regex_stringloop: while (this.regex_string != "") {
            for (const infi in rules) {
                if (count == 0) {
                    throw Error(
                        `変換エラー（無限ループ）: ${this.regex_string}${parsed_regex}`,
                    );
                }
                count--;
                if (
                    this.regex_string != null &&
                    this.regex_string.match(new RegExp(`^${infi}`, "g")) != null
                ) {
                    const searched = this.regex_string.match(
                        new RegExp(`^${infi}`, "g"),
                    );
                    if (searched != null) {
                        const k = rules[infi](
                            this,
                            parsed_regex,
                            this.regex_string,
                            searched[0],
                        );
                        const k0 = k[0];
                        const k1 = k[1];
                        if (Array.isArray(k0)) parsed_regex = k0;
                        if (typeof k1 == "string") this.regex_string = k1;
                        continue regex_stringloop;
                    }
                }
            }
            break regex_stringloop; //通らなかった場合。
        }
        if (![null, ""].includes(this.regex_string)) {
            return Error(`変換エラー:${this.regex_string}${parsed_regex}`);
        }
        return parsed_regex;
    }
}

export { RegExp_Khhyl };

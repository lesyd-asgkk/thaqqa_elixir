
class REK_cond {
        //[ a,b,[c],d,[e,[f,g],h]] = a b (c) d (e (f g) h) のようになってる
        // _に入れる値はunderbar引数にシュートする
    static pc(underbar,rec){
        return REK_cond.calc(underbar,REK_cond.parse(rec));
    }
    static calc(underbar,rec){
        const op_list = ["||","&&","!=","==","<=",">=","<",">"];
        const stack = [];
        for(let i_ = 0 ; i_<rec.length ; i_++){const i = rec[i_];
            if(i == "!"){rec[i_]=!REK_cond.calc(underbar,[rec[i_+1]]);
            rec[i_+1]=null;}
        }
        rec = rec.filter(i => i);
        //console.log(rec);
        for(let i_ = 0 ; i_<rec.length ; i_++){const i = rec[i_];
            const j = stack.length>0?rec[stack.length-1]:null;
            if(Array.isArray(i)) stack.push(underbar,REK_cond.calc(i));
            else if(typeof i =="boolean") stack.push(i);
            else if(i.startsWith("\'")) stack.push(slice=="'true");
            else if(i.startsWith("_")) stack.push(underbar.valueList[i.slice(2)]);
            else stack.push(i);
            if(stack.length && op_list.includes(j) && op_list.includes(i)) throw Error(`1 REK_COND:不正な値:${rec}`);
            if(stack.length && j && !op_list.includes(j) && !op_list.includes(i)) throw Error(`2 REK_COND:不正な値:${rec}`);
            switch(j){
                case "||":
                    stack.unshift( stack[0] || stack[2] );stack.splice(1,Infinity);
                    break;
                case "&&":
                    stack.unshift( stack[0] && stack[2] );stack.splice(1,Infinity);
                    break;
                case "!=":
                    stack.unshift( stack[0] != stack[2] );stack.splice(1,Infinity);
                    break;
                case "==":
                    stack.unshift( stack[0] == stack[2] );stack.splice(1,Infinity);
                    break;
                case "<=":
                    stack.unshift( stack[0] <= stack[2] );stack.splice(1,Infinity);
                    break;
                case "<":
                    stack.unshift( stack[0] < stack[2] );stack.splice(1,Infinity);
                    break;
                case ">=":
                    stack.unshift( stack[0] >= stack[2] );stack.splice(1,Infinity);
                    break;
                case ">":
                    stack.unshift( stack[0] > stack[2] );stack.splice(1,Infinity);
                    break;
                default:
                    break;
            }
        //console.log(`${rec} : ${stack}`);
        }
        return stack[0];
    }
    static parse(str){
        let ans  = [];
        let count = 10000;
        patternloop:while (str != "") {
            //console.log(`${str} `);
            for(const infi in REK_cond.rule){
                if(count == 0) throw Error(`変換エラー（無限ループ）: ${str}${ans}`);
                count--;
                if(str != null && str.match(new RegExp(`^${infi}`,"g")) != null){
                    const searched = str.match(new RegExp(`^${infi}`,"g"));
                    if(searched != null){
                        const k = REK_cond.rule[infi](ans,str,searched[0]);
                        const k0 = k[0];const k1 = k[1];
                        if(Array.isArray(k0)) ans = k0;
                        if(typeof k1 == "string") str = k1;
                        continue patternloop;
                    }
                }
            }
            break patternloop; //通らなかった場合。
        }
        if(![null,""].includes(str)){throw Error(`変換エラー:${str}${ans}`)}
        //console.log(ans);
        return ans;
    }
    static rule = {
        ["\\\("]: (ans, pattern, msg) => {
            return REK_cond.PREsub_br_A(ans, pattern, msg);
          },
        ["(\\\|\\\||&&|!=?|==)"]: (ans, pattern, msg) => {
            return REK_cond.PREsub_END(ans, pattern, msg, msg);
        },
        ["(true|false|TRUE|FALSE)"]: (ans, pattern, msg) => {
            return REK_cond.PREsub_END(ans, pattern, `'${msg.toLowerCase()}`, msg);
          },
        ["(\\\"|\\\')"]: (ans, pattern, msg) => {
            return REK_cond.PREsub_br_B(ans, pattern, msg);
        },
        ["_\\\.[A-Za-z]+"]: (ans, pattern, msg) => {
          return REK_cond.PREsub_END(ans, pattern, msg, msg);
        },
        [" "]: (ans, pattern, msg) => {
          return REK_cond.PREsub_END(ans, pattern, "", msg);
        },
    };
    static PREsub_END(ans,pattern,letter,msg){
        const t = letter;
        ans.push(t);
        pattern = pattern.slice(msg.length);
        return [ans, pattern];
    };
    static PREsub_br_B(ans,pattern,letter){
        const br_start = letter.length;
        let i = 1; // br_end
        for (i = 1; i < pattern.length; i++) {
          if (pattern[i-1]!="\\"&&pattern[i] == letter) break;
          if(i==pattern.length-1) throw Error(`${pattern}『${letter}』が閉じていません`);
        }
        const t = pattern.slice(br_start, i);
        ans.push(t);
        pattern = pattern.slice(i + 1);
        return [ans, pattern];
    };
    static PREsub_br_A(ans,pattern,letter){
        const br_start = letter.length; // ?:や<Name>:とか
        let i = 1; // br_end
        let j = 1; // 
        for (i = 1; i < pattern.length; i++) {
          if (pattern[i] == "(") j++;
          else if (pattern[i] == ")") j--;
          if (j == 0) break;
        }
        if(j!=0) throw Error(`${pattern}(<任意の文字列>)のような括弧類が閉じていません`);
        const t = pattern.slice(br_start, i);
        ans.push(REK_cond.parse(t));
        pattern = pattern.slice(i + 1);
        return [ans, pattern];
    };
}
export {REK_cond}

// (..) : a,b
// _\.[A-Za-z]+ :a,b
// a && b
// a || b
// a ! b
// a == b , a != b 
//こいつらだけを受け付けて演算する。

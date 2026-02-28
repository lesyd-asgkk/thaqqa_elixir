class Render {
    //text:string型
    //lang:0,1の2択
    //alig:-1,0,1の3択
    //option:設定とか
    //size:初期サイズ。普通は16
    //pos:表示位置。

    //text , lang,alig,{option:,size:,pos:,...}とかの形にしたほうが良さそう
    static DrawD(text, lang, alig, option) {
        //option:{font,parse,size,position}
        //console.log(text,lang,alig,option);
        option.font ??= "default";
        switch (option.parse) {
            case "parsedperfect":
                break;
            case "parsedplus":
                text = F_GSUBManager.fgsub(text, alig, option.font);
                break;
            case "parsed":
                text = GSUBManager.gsub(text, alig);
                text = F_GSUBManager.fgsub(text, alig, option.font);
                break;
            default:
                text = Parser.parse(text, lang);
                //console.log(text);
                text = GSUBManager.gsub(text, alig);
                //console.log(text);
                text = F_GSUBManager.fgsub(text, alig, option.font);

                break;
        }
        option.position ??= { x: 0, y: 0 };
        option.align ??= { x: -1, y: -1 };
        option.size ??= 16;
        const glar = new GlyphArray(
            text,
            alig,
            option.font,
            false,
            { top: 800, right: 800, bottom: 800, left: 800 },
            { x: option.position.x, y: option.position.y },
            { x: option.align.x, y: option.align.y },
        );
        const ans = glar.toPath(option.size).toRelativeAll();

        ans.d_str = ans.to_String();
        return ans;
    }
}

export { Render };

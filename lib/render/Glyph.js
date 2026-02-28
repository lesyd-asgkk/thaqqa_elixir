class GlyphArray {
    constructor(name, vec, font, iswrap, box, pos, alg) {
        this.name = name;
        this.font = font;
        this.path = []; //pathに改名予定、new Path();にもする予定
        this.glyphList = []; //Glyphの配列 入れ子にします
        this.attribute = {}; //(将来に属性を付ける場合の為。)
        this.position = { x: pos.x ?? 0, y: pos.y ?? 0 }; //（parentに対するthisのoffset）
        this.aligment = { x: alg.x ?? 0, y: alg.y ?? 0 };
        this.vec = vec; //-1(右から左),0(上から下),1(左から右)
        this.box = box; //{top:0,right:0,bottom:0,left:0};
        this.iswrap = iswrap; // 端で折り返すかどうか(将来用)
        this.initSvg();
    }
    initSvg() {
        //
        const r_ = new RegExp_Khhyl("(L())(L())", {}).ParseRegExp()
            .toNormalRegExp();
        const text = this.name.replaceAll(new RegExp(r_, "g"), "$1Sep()$2")
            .replaceAll(new RegExp(r_, "g"), "$1Sep()$2");

        const pathData = text.split("Sep()");
        pathData.forEach((i) =>
            this.glyphList.push(new Glyph(i, this.vec, this.font))
        );
        if (this.vec == -1) this.glyphList.reverse();
    }

    #to_em(n) { //指定した大きさnに変換する為に倍率をかける関数
        const textdata =
            FontManager.getFont(this.font).getTable("FONTDATA").dataList[0]
                .valueList;
        return n / (this.vec == 0 ? textdata.WidthV : textdata.Height);
    }

    #toPath_horizontal(defaultsize, _prev, _next) {
        const textdata =
            FontManager.getFont(this.font).getTable("FONTDATA").dataList[0]
                .valueList;
        const newline_list = FontManager.getStaticTable("PUNCTUATION").getData({
            "IsNewline": true,
        }).map((i) => i.getVal("Name"));

        let x = this.position.x;
        let y = this.position.y;
        this.path = Path.fromPosition(x, y); //初期位置に移動

        const is_dir_right = this.vec == 1;
        for (let i = 0; i < this.glyphList.length; i++) {
            const size_em = this.#to_em(defaultsize); //将来的に文字サイズを可変にしたいので、単にsize_emと命名。
            const size = defaultsize; //同上

            const glyph_path = this.glyphList[i].toPathAbsolute(
                textdata.Height,
                0.5 +
                    GPOSManager.gpos(
                            this.glyphList[i].fullname,
                            this.vec,
                            "INEX",
                            this.font,
                        ).y1 / textdata.Height,
            ).rescale(size_em);
            const glyph_width = (!textdata.isWidthHRel
                ? size * textdata.WidthV
                : glyph_path.getLeft() + glyph_path.getRight() +
                    size * textdata.WidthV) / textdata.Height;

            let gap_left = 0;
            let gap_right = 0;

            const tmp_for_gap = GPOSManager.gpos(
                this.glyphList[i].fullname,
                this.vec,
                "INEX",
                this.font,
            );
            gap_right += tmp_for_gap.x1;
            gap_left += tmp_for_gap.x0;

            //左側の隙間。前の文字と照らし合わせて調整
            gap_left += GPOSManager.gpos(
                (i == 0
                    ? (_prev ?? "Null()")
                    : this.glyphList[i - 1].fullname) +
                    this.glyphList[i].fullname,
                this.vec,
                "EX",
                this.font,
            ).x1;

            //右側の隙間。前の文字と照らし合わせて調整
            gap_right += GPOSManager.gpos(
                this.glyphList[i].fullname + (i != this.glyphList.length - 1
                    ? this.glyphList[i + 1].fullname
                    : (_next ?? "Null()")),
                this.vec,
                "EX",
                this.font,
            ).x0;

            x += glyph_width / 2 +
                (is_dir_right ? gap_left : gap_right) * size_em;

            this.path.mergePath2(glyph_path, x, y);
            //this.path.concat(Path.fromPosition(x,y)).concat(glyph_path.toRelativeAll()); //文字情報を繋げる

            if (i != this.glyphList.length - 1) {
                x += glyph_width / 2 +
                    (is_dir_right ? gap_right : gap_left) * size_em; //最後の文字で無ければ文字の幅/2分だけ進める
            }
            this.glyphList[i].offset = { x, y }; //offsetを指定しておく
            //改行に差し掛かったときの処理。iswrap対応時はここの条件を追加する。
            if (newline_list.indexOf(this.glyphList[i].name) != -1) {
                x = 0;
                y += size *
                    ((textdata.Height + textdata.TopGapH) / textdata.Height);
            }
        }
        this.path.concat(Path.fromPosition(x, y));
    }

    #toPath_vertical(defaultsize, _prev, _next) {
        this.path = Path.fromPosition(this.position.x, this.position.y); //初期位置に移動
        let x = this.position.x;
        let y = this.position.y;
        const newline_list = FontManager.getStaticTable("PUNCTUATION").getData({
            "IsNewline": true,
        }).map((i) => i.getVal("Name"));
        let isnewline = true;
        for (let i = 0; i < this.glyphList.length; i++) {
            //m0 -> gap_above , m1 -> gap_below
            let gap_above = 0;
            let gap_below = 0;
            const size_em = this.#to_em(defaultsize); //将来的に文字サイズを可変にしたいので、単にsize_emと命名。
            const size = defaultsize; //同上

            const tmp_for_gap = GPOSManager.gpos(
                this.glyphList[i].fullname,
                this.vec,
                "INEX",
                this.font,
            );
            gap_below += tmp_for_gap.y1;
            gap_above += tmp_for_gap.y0;

            //上の隙間。前の文字と照らし合わせて調整
            gap_above += GPOSManager.gpos(
                (i == 0
                    ? (_prev ?? "Null()")
                    : this.glyphList[i - 1].fullname) +
                    this.glyphList[i].fullname,
                this.vec,
                "EX",
                this.font,
            ).y1;

            //下の隙間。次の文字と照らし合わせて調整
            gap_below += GPOSManager.gpos(
                this.glyphList[i].fullname +
                    (i != this.glyphList.length - 1
                        ? this.glyphList[i + 1].fullname
                        : (_next ?? "Null()")),
                this.vec,
                "EX",
                this.font,
            ).y0;

            //当然、上の隙間の分だけ文字情報がズレるので補正
            y += gap_above * size_em;

            const is_isolated = (this.glyphList[i].type == "P") ||
                (this.glyphList[i].form == "sol");
            const glyph_path = this.glyphList[i].toPathRelative(
                !is_isolated ? -gap_above : 0,
                gap_below,
            ).rescale(size_em);
            if (isnewline) { //改行に差し掛かったときの処理。
                y -= ((this.glyphList[i].toPathRelative(0, 0).getTop()) -
                    gap_above) * size_em;
                isnewline = false;
            }
            this.path.mergePath2(glyph_path, x, y);
            this.glyphList[i].offset = { x, y }; //offsetを指定しておく
            //this.path = this.path.concat(Path.fromPosition(x,y)).concat(glyph_path.toRelativeAll()); //文字情報を繋げる
            y += (this.glyphList[i].toPathRelative(0, 0).getBottom() +
                gap_below) * size_em; //文字の長さの分＋隙間分下に進める
            if (i + 1 != this.glyphList.length) {
                const d2 = this.glyphList[i + 1].path;
                y -= d2.getTop() * size_em;
            }

            if (newline_list.indexOf(this.glyphList[i].name) != -1) {
                x -= size;
                y = 0;
                isnewline = true;
            }
        }
        this.path.concat(Path.fromPosition(x, y));
    }

    toPath(defaultsize, _prev, _next) { //_prevは今後用
        if (this.vec == 0) this.#toPath_vertical(defaultsize, _prev, _next);
        else this.#toPath_horizontal(defaultsize, _prev, _next);
        return this.path;
    }
}

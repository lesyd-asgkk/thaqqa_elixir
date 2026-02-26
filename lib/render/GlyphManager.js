import { FontManager, Path, SVG } from "../glpyh/deps.js";

class GlyphManager {
  static load(doc) {
    const svg = doc.getElementsByTagName("PATH");
    let d = "M0,0";
    for (const a of svg) {
      const b_ = a.getAttribute("d");

      if (b_ != null) {
        d += b_ + "M0,0";
      }
    }
  }
  static async loadAll(font) {
    await fetch("/server/FontData/" + font + ".svg")
      .then((response) => response.json())
      .then((data) => {
        /*
        try{
        FontManager.getFont(font).getTable("GLYPH",true);
            FontManager.getFont(font).deleteTable("GLYPH");
            FontManager.getFont(font).createTable({name:"GLYPH"});
            const table = FontManager.getFont(font).getTable("GLYPH");
            table.createColumn("ID","INTEGER","",0);
            table.createColumn("Name","char","",1);
            table.createColumn("Path","char","",2);

            for(const d in data) table.createData({Name:d,Path:Path.parse_string(data[d]).toRelativeAll()});
      }
        catch(_e){
            FontManager.getFont(font).createTable({name:"GLYPH"});
            const table = FontManager.getFont(font).getTable("GLYPH");
            table.createColumn("ID","INTEGER","",0);
            table.createColumn("Name","char","",1);
            table.createColumn("Path","char","",2);

            for(const d in data) table.createData({Name:d,Path:Path.parse_string(data[d]).toRelativeAll()});
        }*/
      })
      .catch((error) => console.error("Error fetching data:", error));
    return new Promise((resolve) => {
      resolve("done");
    });
  }
  static getSVG(name, font) {
    const ans = [];
    const table = FontManager.getFont(font).getTable("GLYPH");
    if (table != null) {
      const data = table.getData({ Name: name });
      data.forEach((i) => ans.push(i.getVal("Path")));
    }
    return ans;
  }
}

export { GlyphManager };

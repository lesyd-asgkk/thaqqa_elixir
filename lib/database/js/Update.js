//アップデートされた場合用？

class Update{
    static #LATEST = [0,0,0];
    static Update(version){
        version??=Update.#LATEST;
        try{
            //アップデート内容（具体的に 別関数に纏めることとする）
            //本体のversionの更新
            return null;
        }
        catch(e){
            throw e;
        }
    }
    static UpdateToVer1(version){

    }

    static UpdateTEMP(version){
        //とりあえず用のアプデ
    }
}

export {Update};
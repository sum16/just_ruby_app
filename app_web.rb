require 'webrick'
require 'erb'
require 'rubygems'
require 'dbi'
require "pry"

class String
    alias_method(:orig_concat, :concat)

    def concat(value)
        if RUBY_VERSION > "1.9"
            orig_concat value.force_encoding('UTF-8')
        else
            orig_concat value
        end
    end

end

config = {
    :port => 8099,
    :DocumentRoot => '.',
}

#拡張子erbのファイルを、ERBを呼び出して処理するERBHandlerと関連づける
WEBrick::HTTPServlet::FileHandler.add_handler("erb", WEBrick::HTTPServlet::ERBHandler)

#WEBrickのHTTP Serverクラスのサーバーインスタンスを生成する
server = WEBrick::HTTPServer.new( config )


#erbのMIME(ファイルの種類を表す情報)タイプを設定
server.config[:MimeTypes]["erb"] = "text/html"


#http://localhost:80/list.erbで呼び出される
server.mount_proc("/list") do |req, res|

    #binding.pry

    p req.query
    p req.query['oparation']

    #oparationの値の後の(.delete, .edit)で分岐
    #正規表現で(0~9の４桁).(editとdelte)でマッチング
    #それぞれの()が順に$1,$2へ入る
    if /([0-9]{1,4}).(edit|delete)/ =~ req.query['oparation']
        target_id = $1
        oparation = $2

        #ERBをERBHandlerを経由せず、直接呼び出して利用
        if oparation == 'delete'
            template = ERB.new( File.read('delete.erb') )
        elsif oparation == 'edit'
            template = ERB.new( File.read('edit.erb') )   
        end
        res.body << template.result( binding )
    else #データが選択されていない場合
        template = ERB.new( File.read('noselect.erb') )
        res.body << template.result( binding )
    end
end



#登録の処理
#localhost:80/entryで呼ばれる
server.mount_proc("/entry") do |req, res|

    p req.query

    dbh = DBI.connect( 'DBI:SQLite3:sample.db')

        #テーブルへデータを追加する
        dbh.do("insert into books values('#{req.query['id']}', '#{req.query['title'].force_encoding("utf-8")}', '#{req.query['author'].force_encoding("utf-8")}', '#{req.query['page']}', '#{req.query['publish_date']}');")

        #データベースとの接続を終了
        dbh.disconnect

        #処理の結果を表示する
        template = ERB.new( File.read('entried.erb') )
        res.body << template.result( binding )
end


#検索の処理
server.mount_proc("/search") do |req, res|

    p req.query

    a = ['id', 'title', 'author', 'page', 'publish_date']
    a.delete_if { |name| req.query[name] == "" }

    if a.empty?
        where_date = ""
    else
        a.map! { |name| "#{name}='#{req.query[name]}'" }
        where_date = "where "+ a.join('or')
    end

      #処理の結果を表示
      template = ERB.new( File.read('search_results.erb') )
      res.body << template.result( binding )
end


#編集の処理

server.mount_proc("/edit") do |req, res|
    p req.query

    #binding.pry

    dbh = DBI.connect( 'DBI:SQLite3:sample.db')
    dbh.do("update books set id = '#{req.query['id']}', title='#{req.query['title'].force_encoding("utf-8")}', author='#{req.query['author'].force_encoding("utf-8")}', page= '#{req.query['page']}', publish_date='#{req.query['publish_date']}' where id = '#{req.query['id']}';" )

    dbh.disconnect

    template = ERB.new( File.read('edited.erb') )
    res.body << template.result( binding )
end

#削除の処理
server.mount_proc("/delete") do |req, res|
    p req.query


    dbh = DBI.connect( 'DBI:SQLite3:sample.db')
    dbh.do("delete from books where id = '#{req.query['id'].force_encoding("utf-8")}';")

    dbh.disconnect

    template = ERB.new( File.read('deleted.erb') )
    res.body << template.result( binding )
end


#Ctrl-cの割り込みがあった場合にサーバーを停止する処理
trap(:INT) do
    server.shutdown
end


#上記記述の処理をこなすサーバーを開始
server.start




#一時寄せ

#p req.query

#dbh = DBI.connect( 'DBI:SQLite3:sample.db')

#idが使われていたら登録できないようにうする
#rows = dbh.select_one("select * form books where id = '#{req.query['id']}'; ")
#if rows
    #データベースとの接続を終了
#    dbh.disconnect

    #処理の結果を表示
    #ERBをERBHandlerを経由せず、直接呼び出して利用
#    template = ERB.new( File.read('noentried.erb') )
#    res.body << template.result( binding )
#else
    #テーブルへデータを追加する
#    dbh.do("insert into books values('#{req.query['id']}', '#{req.query['title']}', '#{req.query['author']}', '#{req.query['page']}', '#{req.query['publish_date']}');")

    #データベースとの接続を終了
#    dbh.disconnect

    #処理の結果を表示する
#    template = ERB.new( File.read('entried.erb') )
#    res.body << template.result( binding )
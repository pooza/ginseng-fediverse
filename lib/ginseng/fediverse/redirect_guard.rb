module Ginseng
  module Fediverse
    # 資格情報を運ぶ要求のガード (#280 / #282)。
    #
    # ⚠⚠ **実装は `ginseng-core` の `Ginseng::HTTP::RedirectGuard` にある (#289)。**
    # ここは名前を残しているだけ。🔴 自前の copy を持っていた間、**「何が資格情報か」の
    # 一覧が gem をまたいで 2 つあり、core 側だけが増えた** — 慣習的な名前のヘッダ
    # （`X-Api-Key` ほか）・userinfo・クエリの資格情報は、この gem の口では見ていなかった。
    #
    # ⚠ **名前を消さない。** 利用側へ、この名前で `prepend` する回避策を案内してある
    # （pooza/tomato-shrieker#1620）。⚠⚠ 新しく挿すときは名前ではなく
    # `Ginseng::HTTP#guard_redirects!` を使う（挿し先を core が持つ）。
    RedirectGuard = Ginseng::HTTP::RedirectGuard
  end
end

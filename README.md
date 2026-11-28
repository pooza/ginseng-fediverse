# ginseng-fediverse

Mastodon・Misskey などの Fediverse のサーバーと話すためのライブラリです。
API のクライアントのほか、投稿本文の解析（ハッシュタグ・メンション・フッタ）と、投稿先でリンク化されないようにする無毒化を持ちます。

`ginseng-core` の上に作っています。

## このリポジトリについて

pooza の自作アプリケーション群のための内部ライブラリです。
MIT ライセンスで公開していますが、GitHub に置いている以上の配布（rubygems.org への公開など）は予定していません。

- 互換性は利用側のアプリの都合で変え、破壊的な変更も major を上げて行います
- 外部での利用を想定したサポートや問い合わせへの対応は行いません
- Issue・PR は受け付けますが、取り込むか・いつ返答するかはお約束できません

## 導入

rubygems.org には無いので、`Gemfile` で GitHub のタグを指定して参照します。
最新のタグは [Releases](https://github.com/pooza/ginseng-fediverse/releases) を見てください。

```ruby
gem 'ginseng-core', github: 'pooza/ginseng-core', tag: 'vX.Y.Z', require: 'ginseng'
gem 'ginseng-fediverse', github: 'pooza/ginseng-fediverse', tag: 'vX.Y.Z', require: 'ginseng/fediverse'
```

⚠ `ginseng-core` も git で宣言してください。宣言が無いと、Bundler は rubygems.org から同じ名前の gem を探しに行きます。

Ruby 3.4 以上が必要です。

## 使い方

`ginseng-core` と同じく、アプリ側で `Ginseng::Package` を include し、必要なクラスを継承して使います。
`Ginseng::Fediverse::Package` も同じ形で、`*_class` を上書きすると gem の内部もアプリのクラスを使うようになります。
詳しくは [ginseng-core の README](https://github.com/pooza/ginseng-core#使い方) を見てください。

## 主なクラス

| クラス | 役割 |
| --- | --- |
| `Ginseng::Fediverse::Service` | API クライアントの基底。nodeinfo、投稿の上限、メディアのアップロード（外部 URL からの取得は宛先を検証する）、ストリーミングの URL |
| `MastodonService` / `MisskeyService` / `MeisskeyService` / `PleromaService` / `MulukhiyaService` | サーバーの種類ごとの実装 |
| `Ginseng::Fediverse::Parser` | 投稿本文の解析。本文とフッタの分離、ハッシュタグ・メンション（`Acct`）の抽出、コマンドの読み取り。`TootParser`（Mastodon）と `NoteParser`（Misskey）がある |
| `Ginseng::Fediverse::TagContainer` | ハッシュタグの集合。表記を畳んで比べる |
| `Ginseng::Fediverse::Text` | 本文そのものの前処理 |
| `Ginseng::Fediverse::Acct` | `@user@host` 形式のアカウント |
| `Ginseng::Fediverse::TootURI` / `NoteURI` | 投稿の URL |

詳しい振る舞いはソースのコメントにあります。

## ライセンス

[MIT](LICENSE.txt)

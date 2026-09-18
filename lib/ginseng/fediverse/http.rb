module Ginseng
  module Fediverse
    # この gem が投稿先へ出す要求の口 (#280 / #282)。
    #
    # 🔴🔴 **資格情報を持つ要求ではリダイレクトを追わない。** ⚠⚠ HTTParty の既定は追従で、
    # **ホストをまたいで外すのは `basic_auth` だけ** — `Authorization` は 301 / 302 でも
    # 307 / 308 でも送られ、🔴 **307 / 308 は本文ごと別ホストへ POST し直す**（#279 の
    # 投稿の口で実測）。⚠ `maintain_method_across_redirects` では塞がらない。
    #
    # ⚠⚠ **口ごとに `follow_redirects: false` を書く形にしない (#280)。** 資格情報付きの
    # 口は 50 以上あり、**足すたびに忘れる**。持っているかどうかで決める。
    #
    # ⚠ **資格情報を持たない要求は従来どおり追う。** 🔴 一律に切ると、nodeinfo の探索の
    # ように**投稿先が正規にリダイレクトを返す経路**が壊れる。
    #
    # ⚠⚠ **上流（`Ginseng::HTTP`）にも「オリジンをまたいだら資格情報を落とす」機構はあるが、
    # `host_validator` を渡した経路にしか無い** (ginseng-core #527 / #568 / #576)。こちらは
    # 投稿先が 1 つに決まっているので、**落として追う**より**追わない**ほうが合っている。
    class HTTP < Ginseng::HTTP
      # ⚠ どのオリジンに対する資格情報かが値の側に書かれていないヘッダ。
      CREDENTIAL_HEADERS = ['authorization', 'cookie', 'proxy-authorization'].freeze

      # ⚠ HTTParty が options で受ける資格情報。**ヘッダを見るだけでは落としきれない。**
      CREDENTIAL_OPTIONS = [:basic_auth, :digest_auth, :cookies].freeze

      # 🔴 **Misskey はトークンを本文に載せる**（`i`）。⚠⚠ ヘッダだけ見ていると、
      # `notes/create` ほか Misskey 系の口が**丸ごと素通りする**。
      CREDENTIAL_BODY_KEYS = [:i, 'i'].freeze

      # ⚠ 3xx に居るがリダイレクトではない。
      NOT_MODIFIED = 304

      [:head, :get, :post, :put, :delete].each do |method|
        define_method(method) do |uri, options = {}|
          return guard_response(super(uri, guard_redirects(options)))
        end
      end

      # ⚠⚠ **`upload` も同じ扱い。** 🔴 添付の口は `Authorization` を持ち、
      # multipart の本文ごと撃ち直されうる。
      def upload(uri, file, options = {})
        return guard_response(super(uri, file, guard_redirects(options)))
      end

      private

      # 🔴🔴 **`upload` は渡した options をそのまま使わない (#280)。** ⚠⚠ 上流は multipart 用の
      # hash を**組み直す**ので、`upload` に `follow_redirects` を混ぜても**黙って捨てられる**
      # （実測で気づいた）。組み立てた**あと**の hash を見て決める。
      #
      # ⚠ **この継ぎ目は `ginseng-core` の新しめの版にしか無い**（古い版は `upload` の中で
      # 直接組んでいた）。🔴 **古い core を差されている利用側では、ここは黙って効かない。**
      def upload_options(file, options)
        return guard_redirects(super)
      end

      # ⚠ **呼び出し側が明示していたら、そちらを優先する。** 口の側で意図して
      # 追わせている（追わせない）場合に、ここで上書きしない。
      def guard_redirects(options)
        return options if options.key?(:follow_redirects)
        return options unless credentials?(options)
        return options.merge(follow_redirects: false)
      end

      def credentials?(options)
        return true if CREDENTIAL_OPTIONS.any? {|key| options[key].present?}
        return true if credential_headers?(options[:headers])
        return credential_body?(options[:payload] || options[:body])
      end

      def credential_headers?(headers)
        return false unless headers.is_a?(Hash)
        return headers.any? do |key, value|
          CREDENTIAL_HEADERS.include?(key.to_s.downcase) && value.present?
        end
      end

      def credential_body?(body)
        return false unless body.is_a?(Hash)
        return CREDENTIAL_BODY_KEYS.any? {|key| body[key].present?}
      end

      # ⚠⚠ **3xx を黙って返さない (#282)。** 追わないと決めた以上、3xx は「投稿先が違う」
      # の合図。🔴 `Ginseng::HTTP` が例外にするのは 400 以上だけで、3xx のログも 2xx と
      # 同じ `info` 1 行なので、**応答を検査しない利用側では「投稿されていないのに成功」
      # と数えられる**（`tomato-shrieker` の `MastodonShrieker` は `return toot(body)`）。
      #
      # ⚠ **追従している要求では、そもそも 3xx は返ってこない**ので、ここが効くのは
      # 資格情報付きの口（＝ 追従を切った口）だけ。
      def guard_response(response)
        code = response.respond_to?(:code) ? response.code : nil
        return response unless code.is_a?(Integer)
        return response unless code.between?(300, 399)
        return response if code == NOT_MODIFIED
        return bad_response!(response)
      end
    end
  end
end

class LinebotsController < ApplicationController
  require 'line/bot'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery except: [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          # 入力した文字をinputに格納
          input = event.message['text']
          case input
          when 'こんにちは'
          	message = { type: 'text', text: "こんにちは！"}
          else
          	client.reply_message(event['replyToken'], message)
	        # search_and_create_messageメソッド内で、楽天APIを用いた商品検索、メッセージの作成を行う
    	    message = search_and_create_message(input)
        	client.reply_message(event['replyToken'], message)
          end
        end
      end
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end

  def search_and_create_message(input)
    RakutenWebService.configuration do |c|
      c.application_id = ENV['RAKUTEN_APPID']
      c.affiliate_id = ENV['RAKUTEN_AFID']
    end
    # 楽天の商品検索APIで画像がある商品の中で、入力値で検索して上から3件を取得する
    # 商品検索+ランキングでの取得はできないため標準の並び順で上から3件取得する
    res = RakutenWebService::Ichiba::Item.search(applicationId:ENV['RAKUTEN_APPID'], affiliateId: ENV['RAKUTEN_AFID'], keyword: input, hits: 10, imageFlag: 1)
    items = []
    # 取得したデータを使いやすいように配列に格納し直す
    items = res.map{|item| item}
    make_reply_content(items)
  end

  def make_reply_content(items)
    {
      "type": 'flex',
      "altText": 'This is a Flex Message',
      "contents":
      {
        "type": 'carousel',
        "contents": [
          make_part(items[0]),
          make_part(items[1]),
          make_part(items[2]),
          make_part(items[3]),
          make_part(items[4]),
          make_part(items[5]),
          make_part(items[6]),
          make_part(items[7]),
          make_part(items[8]),
          make_part(items[9])
        ]
      }
    }
  end

  def make_part(item)
    title = item['itemName']
    price = item['itemPrice'].to_s + "円"
    url = item['affiliateUrl']
    image = item['smallImageUrls'].first
    {
      "type": "bubble",
      "hero": {
        "type": "image",
        "size": "full",
        "aspectRatio": "20:13",
        "aspectMode": "cover",
        "url": image
      },
      "body":
      {
        "type": "box",
        "layout": "vertical",
        "spacing": "sm",
        "contents": [
          {
            "type": "text",
            "text": title,
            "wrap": true,
            "weight": "bold",
            "size": "lg"
          },
          {
            "type": "box",
            "layout": "baseline",
            "contents": [
              {
                "type": "text",
                "text": price,
                "wrap": true,
                "weight": "bold",
                "flex": 0
              }
            ]
          }                      ]
      },
      "footer": {
        "type": "box",
        "layout": "vertical",
        "spacing": "sm",
        "contents": [
          {
            "type": "button",
            "style": "primary",
            "action": {
              "type": "uri",
              "label": "商品ページへ",
              "uri": url
            }
          }
        ]
      }
    }
  end
end
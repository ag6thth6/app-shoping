class LinebotsController < ApplicationController
	require 'line/bot'
	require 'net/http'
	require 'uri'
	require 'rexml/document'

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
			sessionmassage = session[:message]
			if sessionmassage = '楽天'
				if input = 'やめる'
					session[:message] = nil
					message = { type: 'text', text: "やめたで。"}
					client.reply_message(event['replyToken'], message)
				else
					message = search_and_create_message(input)
					client.reply_message(event['replyToken'], message)
				end
			else
				case input
				when 'こんにちは','よう','こんにちわ','こんばんは','こんばんわ'
					cnt = 0
					cnt = cnt + 1
					if cnt = 0
						message = { type: 'text', text: "おす"}
					else
						message = { type: 'text', text: "しつこいなあ"}
					end
					client.reply_message(event['replyToken'], message)
				when '天気'
					message = choice()
					client.reply_message(event['replyToken'], message)
				when '大阪の天気','奈良県北部の天気','奈良県南部の天気','京都府北部の天気','京都府南部の天気'
					message = search_weather(input) 
					client.reply_message(event['replyToken'], message)
				when '京都の天気'
					message = kyoto_choice()
					client.reply_message(event['replyToken'], message)
				when '奈良の天気'
					message = nara_choice()
					client.reply_message(event['replyToken'], message)
				when '楽天'
					session[:message] = "楽天"
					message = message = { type: 'text', text: "楽天な。好きなキーワードを入れろよ。検索するわ。やめたかったら「やめる」って送れ。"}
					client.reply_message(event['replyToken'], message)
				else
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

def choice()
	{
		"type": "text",
		"text": "どこの天気を調べるん？",
		"quickReply": {
			"items": [
				{
					"type": "action",
					"action": {
						"type": "message",
						"label": "大阪",
						"text": "大阪の天気"
					}
				},
				{
					"type": "action",
					"action": {
						"type": "message",
						"label": "京都",
						"text": "京都の天気"
					}
				},
				{
					"type": "action",
					"action": {
						"type": "message",
						"label": "奈良",
						"text": "奈良の天気"
						}
				}
			]
		}
	}
end

def nara_choice()
	{
		"type": "text",
		"text": "奈良のどこや？",
		"quickReply": {
			"items": [
				{
					"type": "action",
					"action": {
						"type": "message",
						"label": "北部",
						"text": "奈良県北部の天気"
					}
				},
				{
					"type": "action",
					"action": {
						"type": "message",
						"label": "南部",
						"text": "奈良県南部の天気"
					}
				}
			]
		}
	}
end

def kyoto_choice()
	{
		"type": "text",
		"text": "京都のどこや？",
		"quickReply": {
			"items": [
				{
					"type": "action",
					"action": {
						"type": "message",
						"label": "北部",
						"text": "京都府北部の天気"
					}
				},
				{
					"type": "action",
					"action": {
						"type": "message",
						"label": "南部",
						"text": "京都府南部の天気"
					}
				}
			]
		}
	}
end

def search_weather(input)
	case input
	when '大阪の天気'
		uri = URI.parse('https://www.drk7.jp/weather/xml/27.xml')
		xpath = 'weatherforecast/pref/area[1]'
	when '奈良県北部の天気'
		uri = URI.parse('https://www.drk7.jp/weather/xml/29.xml')
		xpath = 'weatherforecast/pref/area[1]'
	when '奈良県南部の天気'
		uri = URI.parse('https://www.drk7.jp/weather/xml/29.xml')
		xpath = 'weatherforecast/pref/area[2]'
	when '京都府北部の天気'
		uri = URI.parse('https://www.drk7.jp/weather/xml/26.xml')
		xpath = 'weatherforecast/pref/area[1]'
	when '京都府南部の天気'
		uri = URI.parse('https://www.drk7.jp/weather/xml/26.xml')
		xpath = 'weatherforecast/pref/area[2]'
	end
	xml = Net::HTTP.get(uri)
	doc = REXML::Document.new(xml){
		"type": "template",
		"altText": "this is a carousel template",
		"template": {
			"type": "carousel",
			"columns": [
				create_weatheritem(input,doc,xpath,"1"),
				create_weatheritem(input,doc,xpath,"2"),
				create_weatheritem(input,doc,xpath,"3"),
				create_weatheritem(input,doc,xpath,"4"),
				create_weatheritem(input,doc,xpath,"5"),
				create_weatheritem(input,doc,xpath,"6"),
				create_weatheritem(input,doc,xpath,"7")
			],
			"imageAspectRatio": "rectangle",
			"imageSize": "cover"
		}
	}
end

def create_weatheritem(input,doc,xpath,i)
	date = doc.elements[xpath + '/info[' + i + ']'].attributes["date"]
	weather = doc.elements[xpath + '/info[' + i + ']/weather'].text # 天気（例：「晴れ」）
	img = doc.elements[xpath + '/info[' + i + ']/img'].text
	img = img.sub(/http/,"https")
	max = doc.elements[xpath + '/info[' + i + ']/temperature/range[1]'].text # 最高気温
	min = doc.elements[xpath + '/info[' + i + ']/temperature/range[2]'].text # 最低気温
	per00to06 = doc.elements[xpath + '/info[' + i + ']/rainfallchance/period[1]'].text # 0-6時の降水確率
	per06to12 = doc.elements[xpath + '/info[' + i + ']/rainfallchance/period[2]'].text # 6-12時の降水確率
	per12to18 = doc.elements[xpath + '/info[' + i + ']/rainfallchance/period[3]'].text # 12-18時の降水確率
	per18to24 = doc.elements[xpath + '/info[' + i + ']/rainfallchance/period[4]'].text # 18-24時の降水確率
	{
		"thumbnailImageUrl": img,
		"imageBackgroundColor": "#FFFFFF",
		"title": input + " " + date,
		"text": weather + "\n最高気温：" + max + "度\n最低気温：" + min + "度",
		"actions": [
			{
				"type": "uri",
				"label": "View detail",
				"uri": "https://hyouhikaku.com"
			}
		]
	}
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
			"body": {
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
					}
				]
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

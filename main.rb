require 'rubygems'
require 'sinatra'
# require 'sinatra/reloader' if development?
require 'pry'

# set :sessions, true
use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'your_secret'

SUITS = ['hearts', 'diamonds', 'spades', 'clubs']
VALUES = ['ace',2,3,4,5,6,7,8,9,10,'jack','queen','king']
MAX_BET = 500
MIN_BET = 10

helpers do
  def image_of(card)
    '<img src="/images/cards/'+card[0]+'_'+card[1].to_s+".jpg\" alt=\""+card[1].to_s+' of '+card[0]+'">'
  end

  def card_cover
    '<img src="/images/cards/cover.jpg" alt="card cover">'
  end

  def create_deck
    session[:deck] = []
    SUITS.each do |suit|
      VALUES.each do |value|
        card = [suit,value]
        session[:deck] << card
      end
    end
    session[:deck].shuffle!
  end

  def player_deal
    session[:player_cards] << session[:deck].pop
  end

  def dealer_deal
    session[:dealer_cards] << session[:deck].pop
  end

  def dealer_reach_17?
    total = calculate_total(session[:dealer_cards])
    if total >= 17
      true
    else
      false
    end
  end

  def blackjack?(cards)
    calculate_total(cards) == 21 ? session[:blackjack][0] = true : session[:blackjack][0] = false
  end

  def bust?(cards)
    calculate_total(cards) > 21 ? session[:bust][0] = true : session[:bust][0] = false
  end

  def player_turn
    blackjack?(session[:player_cards])
    bust?(session[:player_cards])
    session[:blackjack][1] = session[:player_name] if session[:blackjack][0]
    session[:bust][1] = session[:player_name] if session[:bust][0]
    unless session[:blackjack][0] || session[:bust][0]
      player_deal
    end
  end

  def calculate_total(cards)
    face_cards = ['jack', 'queen', 'king']
    total = 0
    ace_count = 0
    cards.each do |card|
      if card[1] == 'ace'
        total += 11
        ace_count += 1
      elsif face_cards.include?(card[1])
        total += 10
      else
        total += card[1]
      end
    end
    total -= (ace_count * 10) if total > 21
    total
  end
end

get '/' do
  session[:player_bank] = 0
  session[:total_winnings] = 0
  session[:games_won] = 0
  session[:games_lost] = 0
  session[:games_tied] = 0
  session[:blackjack] = []
  session[:bust] = []
  session[:stand] = false
  create_deck
  if session[:player_name]
    redirect '/profile'
  else
    redirect '/set_name'
  end
end

get '/set_name' do
  session[:player_name] = nil
  session[:player_bank] = 0
  erb :set_name
end

post '/set_name' do
  session[:player_name] = params[:player_name]
  redirect '/add_bank'
end

get '/profile' do
  erb :profile
end

post '/add_bank' do
  redirect '/add_bank' if params[:buyin].to_i < MIN_BET
  session[:player_bank] += params[:buyin].to_i
  redirect '/profile'
end

get '/add_bank' do
  erb :add_bank
end

get '/confirm_bank' do
  erb :confirm_bank
end

post '/hit' do
  player_turn
  blackjack?(session[:player_cards])
  bust?(session[:player_cards])
  redirect '/game_over' if session[:blackjack][0] || session[:bust][0]
  redirect '/game'
end

post '/stand' do
  session[:bank] += (session[:bet]*3) if session[:blackjack][0]
  session[:stand] = true
  redirect '/game_over' if session[:blackjack][0] || session[:bust][0]
  redirect '/game'
end

post '/play' do
  redirect '/bet'
end

post '/bet' do
  session[:bet] = params[:bet]
  session[:player_bank] -= params[:bet].to_i
  redirect '/init'
end

get '/bet' do
  erb :bet
end

post '/play_again' do
  redirect '/bet'
end

get '/init' do
  session[:player_cards] = []
  session[:dealer_cards] = []
  player_deal
  dealer_deal
  player_deal
  dealer_deal
  blackjack?(session[:player_cards])
  bust?(session[:player_cards])
  redirect '/game_over' if session[:blackjack][0] || session[:bust][0]
  redirect '/game'
end

get '/game' do
  erb :game
end

get '/game_over' do
  erb :game_over
end


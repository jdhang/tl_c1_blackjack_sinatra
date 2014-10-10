require 'rubygems'
require 'sinatra'
# require 'sinatra/reloader' if development?
require 'pry'

# set :sessions, true
use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'your_secret'

SUITS = ['Hearts', 'Diamonds', 'Spades', 'Clubs']
VALUES = ['Ace',2,3,4,5,6,7,8,9,10,'Jack','Queen','King']
MAX_BET = 500
MIN_BET = 10

helpers do
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
    calculate_total(cards) == 21 ? session[:blackjack] = true : session[:blackjack] = false
  end

  def bust?(cards)
    calculate_total(cards) > 21 ? session[:bust] = true : session[:bust] = false
  end

  def dealer_turn
    blackjack?(session[:dealer_cards])
    bust?(session[:dealer_cards])
    unless dealer_reach_17? || session[:blackjack] || session[:bust]
      begin
        dealer_deal        
      end until dealer_reach_17? || session[:blackjack] || session[:bust]
    end
  end

  def player_turn
    blackjack?(session[:player_cards])
    bust?(session[:player_cards])
    unless session[:blackjack] || session[:bust]
      player_deal
    end
  end

  def calculate_total(cards)
    face_cards = ['Jack', 'Queen', 'King']
    total = 0
    ace_count = 0
    cards.each do |card|
      if card[1] == 'Ace'
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
  session[:player_name] = "Player"
  session[:total_winnings] = 0
  session[:games_won] = 0
  session[:games_lost] = 0
  session[:games_tied] = 0
  create_deck
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
  redirect '/confirm_bank'
end

get '/add_bank' do
  erb :add_bank
end

get '/confirm_bank' do
  erb :confirm_bank
end

get '/hit' do
  player_turn
   blackjack?(session[:player_cards])
  bust?(session[:player_cards])
  redirect '/game'
end

get '/dealer_turn' do
  dealer_turn
  redirect '/game'
end

post '/bet' do
  session[:bet] = params[:bet]
  session[:player_bank] -= params[:bet].to_i
  redirect '/init'
end

get '/bet' do
  erb :bet
end

get '/play_again' do
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
  redirect '/game'
end

get '/game' do
  erb :game
end


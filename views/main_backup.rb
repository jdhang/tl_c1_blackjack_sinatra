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
      blackjack?(session[:player_cards])
      bust?(session[:player_cards])
      session[:blackjack][1] = session[:player_name] if session[:blackjack][0]
      session[:bust][1] = session[:player_name] if session[:bust][0]
    end
    collect
  end

  def dealer_turn
    blackjack?(session[:dealer_cards])
    bust?(session[:dealer_cards])
    session[:blackjack][1] = "Dealer" if session[:blackjack][0]
    session[:bust][1] = "Dealer" if session[:bust][0]
    unless session[:blackjack][0] || session[:bust][0] || dealer_reach_17?
      begin
        dealer_deal
        blackjack?(session[:dealer_cards])
        bust?(session[:dealer_cards])
        session[:blackjack][1] = "Dealer" if session[:blackjack][0]
        session[:bust][1] = "Dealer" if session[:bust][0]
      end until session[:blackjack][0] || session[:bust][0] || dealer_reach_17?
    end
    collect
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

  def compare_hands
    dealer_total = calculate_total session[:dealer_cards]
    player_total = calculate_total session[:player_cards]
    if dealer_total == player_total
      session[:games_tied] += 1
      session[:winnings] = session[:bet].to_i
      session[:player_bank] += session[:winnings]
      session[:total_winnings] += session[:winnings]
      "It's a tie! You get $"+session[:bet].to_s+" back!"
    elsif player_total > dealer_total
      session[:games_won] += 1
      session[:winnings] = (session[:bet].to_i)*2
      session[:player_bank] += session[:winnings]
      session[:total_winnings] += session[:winnings]
      session[:player_name]+"'s hand is higher! You win $"+session[:winnings].to_s+"!"
    else
      session[:games_lost] += 1
      "Dealer's hand is higher! You lose $"+session[:bet].to_s+"!"
    end
  end

  def result
    if session[:blackjack][0] && session[:player_name] == session[:blackjack][1]
      session[:games_won] += 1
      "Blackjack! "+session[:player_name]+" wins $"+session[:winnings].to_s+"!"
    elsif session[:bust][0] && session[:player_name] == session[:bust][1]
      session[:games_lost] += 1
      "Bust! "+session[:player_name]+" loses $"+session[:bet].to_s+"!"
    elsif session[:blackjack][0] && session[:blackjack][1] == "Dealer"
      session[:games_lost] += 1
      "Dealer Blackjack! You lose $"+session[:bet].to_s+"!"
    elsif session[:bust][0] && session[:blackjack][1] == "Dealer"
      session[:games_won] += 1
      "Dealer Bust! You win $"+session[:bet].to_s+"!"
    end
  end

  def collect
    if session[:blackjack][0] && session[:bust][1] == session[:player_name]
      session[:winnings] = (session[:bet].to_i)*3
    elsif session[:bust][0] && session[:bust][1] == "Dealer"
      session[:winnings] = (session[:bet].to_i)*2
    else 
      session[:winnings] = 0
    end
    session[:player_bank] += session[:winnings]
    session[:total_winnings] += session[:winnings]
  end
end

get '/' do
  session[:player_name] = nil
  session[:player_bank] = 0
  session[:total_winnings] = 0
  session[:winnings] = 0
  session[:rounds] = 0
  session[:games_won] = 0
  session[:games_lost] = 0
  session[:games_tied] = 0
  session[:blackjack] = [false, ""]
  session[:bust] = [false, ""]
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
  redirect '/game_over' if session[:blackjack][0] || session[:bust][0]
  redirect '/game'
end

post '/stand' do
  session[:stand] = true
  dealer_turn unless session[:blackjack][0] || session[:bust][0]
  redirect '/game_over' if session[:blackjack][0] || session[:bust][0] || dealer_reach_17?
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
  session[:stand] = false
  session[:rounds] += 1
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
  blackjack?(session[:dealer_cards])
  bust?(session[:dealer_cards])
  redirect '/game_over' if session[:blackjack][0] || session[:bust][0]
  redirect '/game'
end

get '/game' do
  erb :game
end

get '/game_over' do
  erb :game_over
end


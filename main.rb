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
  def initialize_game
    session[:player_cards] = []
    session[:dealer_cards] = []
    create_deck
    2.times do
      player_deal
      dealer_deal
    end
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

  def image_of(card)
    '<img src="/images/cards/'+card[0]+'_'+card[1].to_s+".jpg\" alt=\""+card[1].to_s+' of '+card[0]+'">'
  end

  def card_cover
    '<img src="/images/cards/cover.jpg" alt="card cover">'
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

  def dealer_hit
    total = calculate_total(session[:dealer_cards])
    unless total >= 17 || total > 21 || total == 21
      begin
        dealer_deal
        total = calculate_total(session[:dealer_cards])
      end until total >= 17 || total > 21 || total == 21
    end
  end

  def check_blackjack_or_bust
    total = calculate_total(session[:player_cards])
    if total > 21
      @error = "Bust! You lose $"+session[:bet].to_s
      @show_option_pane = false
      session[:games_lost] += 1
    elsif total == 21
      @success = "Blackjack! You win $"+session[:bet].to_s
      @show_option_pane = false
      session[:total_winnings] += session[:bet]
      session[:player_balance] += (session[:bet])*2
      session[:games_won] += 1
    end
  end

  def check_dealer_and_winner
    total = calculate_total(session[:dealer_cards])
    p_total = calculate_total(session[:player_cards])
    if total > 21
      @success = "Dealer Bust! You win $"+session[:bet].to_s
      @show_option_pane = false
      session[:total_winnings] += session[:bet]
      session[:player_balance] += (session[:bet])*2
      session[:games_won] += 1
    elsif total == 21
      @error = "Dealer Blackjack! You lose $"+session[:bet].to_s
      @show_option_pane = false
      session[:games_lost] += 1
    elsif p_total == total
      @success = "It's a tie! You get your bet back!"
      @show_option_pane = false
      session[:games_tied] += 1
    elsif p_total > total
      @success = "You have the higher hand! You win $"+session[:bet].to_s
      @show_option_pane = false
      session[:total_winnings] += session[:bet]
      session[:player_balance] += (session[:bet])*2
      session[:games_won] += 1
    elsif total > p_total
      @error = "Dealer has the higher hand! You lose $"+session[:bet].to_s
      @show_option_pane = false
      session[:games_lost] += 1
    end
  end
end

before do
  @show_option_pane = true
  @hide_player_info = false
end

get '/' do
  session[:player_name] = nil
  session[:bet] = 0
  session[:player_balance] = 0
  session[:total_winnings] = 0
  session[:games_won] = 0
  session[:games_lost] = 0
  session[:games_tied] = 0
  session[:rounds] = 0
  erb :set_name
end

get '/game/player/set_name' do
  erb :set_name
end

post '/game/player/set_name' do
  if params[:player_name] == ""
    @error = "You must enter a player name!"
    erb :set_name
  else
    session[:player_name] = params[:player_name]
    redirect '/game/player/buyin'
  end
end

get '/game/player/buyin' do
  erb :add_balance
end

post '/game/player/buyin' do
  if params[:buyin] == ""
    @error = "You need to enter a value in order to buy in!"
    erb :add_balance
  elsif params[:buyin].to_i == 0 && params[:bet] == 0
    @error = "You entered an invalid value!"
    erb :add_balance
  else
    session[:player_balance] += params[:buyin].to_i
    redirect '/game/player/profile'
  end
end

get '/game/player/add_balance' do
  erb :add_balance
end

post '/game/player/add_balance' do
  erb :add_balance
end

get '/game/player/profile' do
  erb :profile
end

post '/game/play' do
  if session[:player_balance] == 0
    @error = "You need some money to play!"
    erb :profile
  else
    redirect '/game/player/bet'
  end
end

post '/game/player/bet' do
  if params[:bet] == ""
    @error = "You need to enter a bet in order to play!"
    erb :bet
  elsif params[:bet].to_i == 0 && params[:bet] == 0
    @error = "You entered an invalid value!"
    erb :bet
  elsif (session[:player_balance]-params[:bet].to_i)<0
    @error = 'You don\'t have enough to bet that amount! You should <a href="/game/player/add_balance" class="alert-link">add to your balance</a>.'
    erb :bet
  elsif params[:bet].to_i > MAX_BET
    @error = "That bet is above the maximum bet limit!"
    erb :bet
  elsif params[:bet].to_i < MIN_BET
    @error = "That bet is below the minimum bet limit!"
    erb :bet
  else
    session[:bet] = params[:bet].to_i
    session[:player_balance] -= session[:bet]
    redirect '/game/initialize'
  end
end

get '/game/player/bet' do
  erb :bet
end

get '/game/initialize' do
  initialize_game
  session[:rounds] += 1
  redirect '/game'
end

get '/game' do
  check_blackjack_or_bust
  erb :game
end

post '/game/player/hit' do
  player_deal
  check_blackjack_or_bust
  erb :game
end

post '/game/player/stand' do
  @flip_card = true
  erb :game
end

post '/game/dealer/flip' do
  @flip = true
  @flip_card = false
  @dealer_turn = true
  unless calculate_total(session[:dealer_cards]) < 17
    check_dealer_and_winner
    @dealer_turn = false
  end
  erb :game
end

post '/game/dealer/hit' do
  dealer_hit
  check_dealer_and_winner
  @flip = true
  erb :game
end

post '/game/play_again/yes' do
  if session[:player_balance] == 0
    @error = 'You need to <a href="/game/player/add_balance" class="alert-link">add to your balance</a> in order to play again!'
    @show_option_pane = false
    erb :game
  else
    redirect '/game/player/bet'
  end
end

post '/game/play_again/no' do
  redirect '/game_over'
end

get '/game_over' do
  @hide_player_info = true
  @game_over = true
  erb :game_summary
end
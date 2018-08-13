require "sinatra"
require "sinatra/reloader"
require 'data_mapper'
require_relative "models/konto"
require_relative "models/ueberweisung"

DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

DataMapper.finalize.auto_upgrade!

enable :sessions

# index------------------------------------------

get "/" do
  erb :"index/index"
end

get "/konten/:id/logged_in_index" do
  if logged_in?
    @logged_in = logged_in?
    @konto_id = Konto.get(params["id"])
    @konto_nr = @konto_id.konto_nr
    erb :"index/logged_in_index"
  else
    redirect "/"
  end
end

# konten-----------------------------------------

get "/konten" do
  @konten = Konto.all
  erb :"konto_management/konten_liste"
end

# konto_management-------------------------------

get "/konten/new" do
  erb :"konto_management/create_konto"
end

post "/konten/create_konto" do
  if params["konto_nr"].size == 4
    @konto = Konto.first(konto_nr: params["konto_nr"])
    if @konto.nil?
      if params["pin"].size == 3
        Konto.create(konto_nr: params["konto_nr"], pin: params["pin"])
        redirect "/"
      else
        @err_msg = "Die Pin muss aus 3 Ziffern und/oder Buchstaben bestehen"
        erb :"konto_management/create_konto"
      end
    else
      @err_msg = "Die angegebene Kontonummer existiert bereits"
      erb :"konto_management/create_konto"
    end
  else
    @err_msg = "Die Kontonummer muss aus 4 Ziffern bestehen"
    erb :"konto_management/create_konto"
  end
end

get "/konten/:id/delete" do
  @konto = Konto.get(params["id"])
  @konto_id = @konto.id
  erb :"konto_management/delete_konto"
end

post "/konten/:id/deleted" do
  @lösche_konto = Konto.get(params["id"])
  @konto_id = @lösche_konto.id
  if !@lösche_konto.nil?
    if @lösche_konto.authenticated?(params["lösche_pin"])
      @lösche_konto.destroy
      redirect "/"
    else
      @err_msg = "Die angegebene Pin stimmt nicht mit der zugehörigen Kontonummer überein"
      erb :"konto_management/delete_konto"
    end
  else
    @err_msg = "Das angegebene Konto ist nicht vorhanden"
    erb :"konto_management/delete_konto"
  end
end

get "/konten/login" do
  erb :"konto_management/login_konto"
end

post "/login" do
  @konto_nr = params["login_konto_nr"]
  @konto = Konto.first(konto_nr: @konto_nr)
  if !@konto.nil?
    if @konto.authenticated?(params["login_pin"])
      setze_aktuelle_konto(@konto_nr)
      redirect "/konten/#{@konto.id}/logged_in_index"
    else
      @err_msg = "Ihre Kontonummer und die angegebene Pin stimmen nicht überein"
      erb :"konto_management/login_konto"
    end
  else
    @err_msg = "Das angegebene Konto existiert nicht"
    erb :"konto_management/login_konto"
  end
end

get "/konten/:id/logout" do
  setze_aktuelle_konto(nil)
  redirect "/"
end

# konto_auszug-----------------------------------

get "/konten/:id/kontoauszug" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  @kontostand = @konto.kontostand
  erb :"konto_actions/konto_auszug"
end

# konto_einzahlen_auszahlen----------------------

get "/konten/:id/geld_einzahlen" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  erb :"konto_actions/konto_einzahlen"
end

post "/konten/:id/einzahlen" do
  @logged_in = logged_in?
    @konto = Konto.get(params["id"])
    @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto_nr)
  if params["betrag"].to_i > 0
    @konto.add_new_ueberweisung(@konto_nr, params["betrag"].to_i, "EINZAHLUNG")
    redirect "/konten/#{@konto.id}/logged_in_index"
  else
    @err_msg = "Ihre eingabe war inkorrekt"
    erb :"konto_actions/konto_einzahlen"
  end
end

get "/konten/:id/geld_auszahlen" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  erb :"konto_actions/konto_auszahlen"
end

post "/konten/:id/auszahlen" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  if params["betrag"].to_i > 0
    @konto.add_new_ueberweisung(@konto_nr, -params["betrag"].to_i, "AUSZAHLUNG")
    redirect "/konten/#{@konto.id}/logged_in_index"
  else
    @err_msg = "Ihre eingabe war inkorrekt"
    erb :"konto_actions/konto_auszahlen"
  end
end

# konto_überw4567eisung------------------------------

get "/konten/:id/geld_ueberweisen" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  erb :"konto_actions/konto_ueberweisen"
end

post "/konten/:id/ueberweisen" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  if params["betrag"].to_i > 0
    @konto.add_new_ueberweisung(params["ziel"], -params["betrag"].to_i, "ÜBERWEISUNG")
    redirect "/konten/#{@konto.id}/logged_in_index"
  else
    @err_msg = "Ihre eingabe ware inkorrekt"
    erb :"konto_actions/konto_ueberweisen"
  end
end

# konto_pin_ändern-------------------------------

get "/konten/:id/edit" do
  @konto = Konto.get(params["id"])
  @konto_id = @konto.id
  erb :"konto_management/pin_aendern/pin_alt"
end

post "/konten/:id/new_pin" do
  @konto = Konto.get(params["id"])
  @konto_id = @konto.id
  if params["pin_alt"] == @konto.pin
    erb :"konto_management/pin_aendern/pin_neu"
  else
    @err_msg = "Ihre eingegebene Pin stimmt nicht mit ihrem Konto überein"
    erb :"konto_management/pin_aendern/pin_alt"
  end
end

post "/konten/:id/pin_aendern" do
  @konto = Konto.get(params["id"])
  @konto_id = @konto.id
  @pin1 = params["pin_neu1"]
  @pin2 = params["pin_neu2"]
  if @pin1.size == 3 && @pin1 == @pin2
    @konto.aendere_pin(@pin1)
    @neue_pin = @pin1
    erb :"konto_management/pin_aendern/pin_verification"
  else
    @err_msg = "Ihre eingaben stimmen nicht überein oder sind nicht 3-stellig"
    erb :"konto_management/pin_aendern/pin_neu"
  end
end

# def's------------------------------------------

def aktuelle_konto
  @aktuelle_konto ||=
  if session[:aktuelle_konto]
    Konto.first(konto_nr: [session[:aktuelle_konto]])
  end
end

def logged_in?
  aktuelle_konto != nil
end

def setze_aktuelle_konto(konto_nr)
  session[:aktuelle_konto] = konto_nr
end

def redirect_if_not_logged_in(konto_nr)
  if !logged_in? || aktuelle_konto.konto_nr != konto_nr
    setze_aktuelle_konto(nil)
    redirect "/"
  end
end

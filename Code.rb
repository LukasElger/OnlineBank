require "sinatra"
require "sinatra/reloader"
require_relative "models/konto_manager"
require_relative "models/konto"
require_relative "models/ueberweisung"

require 'data_mapper'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

enable :sessions

# index------------------------------------------

get "/" do
  erb :"index/index"
end

get "/konten/:konto_nr/logged_in_index" do
  if logged_in?
    @logged_in = logged_in?
    @konto_nr = params["konto_nr"]
    erb :"index/logged_in_index"
  else
    redirect "/"
  end
end

# konten-----------------------------------------

get "/konten" do
  @konten = konto_manager.konten
  erb :"konto_management/konten_liste"
end

# konto_management-------------------------------

get "/konten/new" do
  erb :"konto_management/create_konto"
end

post "/konten/create_konto" do
  if params["konto_nr"].size == 4
    if konto_manager.konten[params["konto_nr"].to_s].nil?
      if params["pin"].size == 3
        konto_manager.add_new_konto(params["konto_nr"], params["pin"], 0)
        konto_manager.store_to_file
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

get "/konten/:konto_nr/delete" do
  @konto_nr = params["konto_nr"]
  erb :"konto_management/delete_konto"
end

post "/konten/:konto_nr/deleted" do
  @konto_nr = params["konto_nr"]
  @lösche_konto = konto_manager.konten[@konto_nr]
  if !@lösche_konto.nil?
    if @lösche_konto.authenticated?(params["lösche_pin"])
      konto_manager.delete_konto(@konto_nr)
      konto_manager.store_to_file
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
  @konto = konto_manager.konten[@konto_nr.to_s]
  if !@konto.nil?
    if @konto.authenticated?(params["login_pin"])
      setze_aktuelle_konto(@konto_nr)
      redirect "/konten/#{@konto_nr}/logged_in_index"
    else
      @err_msg = "Ihre Kontonummer und die angegebene Pin stimmen nicht überein"
      erb :"konto_management/login_konto"
    end
  else
    @err_msg = "Das angegebene Konto existiert nicht"
    erb :"konto_management/login_konto"
  end
end

get "/konten/:konto_nr/logout" do
  setze_aktuelle_konto(nil)
  redirect "/"
end

# konto_auszug-----------------------------------

get "/konten/:konto_nr/kontoauszug" do
  @konto_nr = params["konto_nr"]
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  @kontostand = konto_manager.konten[params["konto_nr"]].kontostand
  @konto = konto_manager.konten[params["konto_nr"]]
  erb :"konto_actions/konto_auszug"
end

# konto_einzahlen_auszahlen----------------------

get "/konten/:konto_nr/geld_einzahlen" do
  @konto_nr = params["konto_nr"]
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  erb :"konto_actions/konto_einzahlen"
end

post "/konten/:konto_nr/einzahlen" do
  @logged_in = logged_in?
  @konto_nr = params["konto_nr"]
  redirect_if_not_logged_in(@konto_nr)
  if params["betrag"].to_i > 0
    konto_manager.konten[@konto_nr].add_new_ueberweisung(@konto_nr, @konto_nr, params["betrag"].to_i, "EINZAHLUNG")
    konto_manager.konten[@konto_nr].ueberweisung_to_csv
    redirect "/konten/#{@konto_nr}/logged_in_index"
  else
    @err_msg = "Ihre eingabe war inkorrekt"
    erb :"konto_actions/konto_einzahlen"
  end
end

get "/konten/:konto_nr/geld_auszahlen" do
  @konto_nr = params["konto_nr"]
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  erb :"konto_actions/konto_auszahlen"
end

post "/konten/:konto_nr/auszahlen" do
  @konto_nr = params["konto_nr"]
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  if params["betrag"].to_i > 0
    konto_manager.konten[@konto_nr].add_new_ueberweisung(@konto_nr, @konto_nr, -params["betrag"].to_i, "AUSZAHLUNG")
    konto_manager.konten[@konto_nr].ueberweisung_to_csv
    redirect "/konten/#{@konto_nr}/logged_in_index"
  else
    @err_msg = "Ihre eingabe war inkorrekt"
    erb :"konto_actions/konto_auszahlen"
  end
end

# konto_überw4567eisung------------------------------

get "/konten/:konto_nr/geld_ueberweisen" do
  @konto_nr = params["konto_nr"]
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  erb :"konto_actions/konto_ueberweisen"
end

post "/konten/:konto_nr/ueberweisen" do
  @konto_nr = params["konto_nr"]
  redirect_if_not_logged_in(@konto_nr)
  @logged_in = logged_in?
  if params["betrag"].to_i > 0
    konto_manager.konten[@konto_nr].ausgehenede_ueberweisung(params["ziel"], -params["betrag"].to_i, "ÜBERWEISUNG")
    konto_manager.konten[@konto_nr].ueberweisung_to_csv
    redirect "/konten/#{@konto_nr}/logged_in_index"
  else
    @err_msg = "Ihre eingabe ware inkorrekt"
    erb :"konto_actions/konto_ueberweisen"
  end
end

# konto_pin_ändern-------------------------------

get "/konten/:konto_nr/edit" do
  @konto_nr = params["konto_nr"]
  erb :"konto_management/pin_aendern/pin_alt"
end

post "/konten/:konto_nr/new_pin" do
  @konto_nr = params["konto_nr"]
  if params["pin_alt"] == konto_manager.konten[@konto_nr].pin
    erb :"konto_management/pin_aendern/pin_neu"
  else
    @err_msg = "Ihre eingegebene Pin stimmt nicht mit ihrem Konto überein"
    erb :"konto_management/pin_aendern/pin_alt"
  end
end

post "/konten/:konto_nr/pin_aendern" do
  @konto_nr = params["konto_nr"]
  @pin1 = params["pin_neu1"]
  @pin2 = params["pin_neu2"]
  if @pin1.size == 3 && @pin1 == @pin2
    konto_manager.konten[@konto_nr].aendere_pin(@pin1)
    konto_manager.store_to_file
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
    konto_manager.konten[session[:aktuelle_konto]]
  end
end

def logged_in?
  aktuelle_konto != nil
end

def setze_aktuelle_konto(konto_nr)
  session[:aktuelle_konto] = konto_nr
end

def konto_manager
  @konto_manager ||= KontoManager.new
end

def redirect_if_not_logged_in(konto_nr)
  if !logged_in? || aktuelle_konto.konto_nr != konto_nr
    setze_aktuelle_konto(nil)
    redirect "/"
  end
end

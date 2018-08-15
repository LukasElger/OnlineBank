require "sinatra"
require "sinatra/reloader"
require 'data_mapper'
require_relative "models/konto"
require_relative "models/ueberweisung"
require "json"

DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

DataMapper.finalize.auto_upgrade!

enable :sessions

get "/" do
  @err_msg = "Login fehlerhaft"
  JSON.generate error(@err_msg)
end

# konten-----------------------------------------

get "/konten" do
  @konten = Konto.all
  @json = []
  if params["search"]
    @konten.each do |konto|
      if konto.konto_nr.include?(params["search"])
        @json << konto.as_json
      end
    end
  else
    @konten.each do |konto|
      @json << konto.as_json
    end
  end
  JSON.generate @json
end

# konto_management-------------------------------

get "/konten/create_konto" do
  if params["konto_nr"].size == 4
    @konto = Konto.first(konto_nr: params["konto_nr"])
    if @konto.nil?
      if params["pin"].size == 3
        Konto.create(konto_nr: params["konto_nr"], pin: params["pin"])
        json_response["message"] = "Konto erfoglreich erstellt"
        json_response["erstelltes Konto"] = Konto.last
        JSON.generate json_response
      else
        @err_msg = "Die Pin muss aus 3 Ziffern und/oder Buchstaben bestehen"
        JSON.generate error(@err_msg)
      end
    else
      @err_msg = "Die angegebene Kontonummer existiert bereits"
      JSON.generate error(@err_msg)
    end
  else
    @err_msg = "Die Kontonummer muss aus 4 Ziffern bestehen"
    JSON.generate error(@err_msg)
  end
end

get "/konten/:id" do
  @konto = Konto.get(params["id"])
  JSON.generate @konto.as_json
end

get "/konten/:id/delete_konto" do
  @lösche_konto = Konto.get(params["id"])
  @konto_id = @lösche_konto.id
  if !@lösche_konto.nil?
    if @lösche_konto.authenticated?(params["lösche_pin"])
      @lösche_konto.destroy
      json_response["message"] = "Konto erfoglreich gelöscht"
      json_response["gelöschtes Konto"] = @lösche_konto.as_json
      JSON.generate json_response
    else
      @err_msg = "Die angegebene Pin stimmt nicht mit der zugehörigen Kontonummer überein"
      JSON.generate error(@err_msg)
    end
  else
    @err_msg = "Das angegebene Konto ist nicht vorhanden"
    JSON.generate error(@err_msg)
  end
end


# konto_auszug-----------------------------------

get "/konten/:id/kontoauszug" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  @logged_in = logged_in?
  @kontostand = @konto.kontostand
  @json = []
  if params["search"]
    @konto.ueberweisungen.each do |ueberweisung|
      if ueberweisung.verwendungszweck.include?(params["search"])
        @json << ueberweisung.as_json
      end
    end
  else
    @konto.ueberweisungen.each do |ueberweisung|
      @json << ueberweisung.as_json
    end
  end
  JSON.generate @json
end

# konto_einzahlen_auszahlen----------------------
get "/konten/:id/einzahlen" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto)
  @logged_in = logged_in?
  if params["betrag"].to_i > 0
    @konto.add_new_ueberweisung(@konto_nr, params["betrag"].to_i, "EINZAHLUNG")
    @ueberweisung = @konto.ueberweisungen.last
    json_response["message"] = "Einzahlung erfoglreich"
    json_response["ueberweisung"] = @ueberweisung.as_json
    JSON.generate json_response
  else
    @err_msg = "Ihre eingabe war inkorrekt"
    JSON.generate error(@err_msg)
  end
end

get "/konten/:id/auszahlen" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto)
  @logged_in = logged_in?
  if params["betrag"].to_i > 0
    @konto.add_new_ueberweisung(@konto_nr, -params["betrag"].to_i, "AUSZAHLUNG")
    @ueberweisung = @konto.ueberweisungen.last
    json_response["message"] = "Auzahlung erfoglreich"
    json_response["ueberweisung"] = @ueberweisung.as_json
    JSON.generate json_response
  else
    @err_msg = "Ihre eingabe war inkorrekt"
    JSON.generate error(@err_msg)
  end
end

# konto_überweisung------------------------------

get "/konten/:id/ueberweisen" do
  @konto = Konto.get(params["id"])
  @konto_nr = @konto.konto_nr
  redirect_if_not_logged_in(@konto)
  @logged_in = logged_in?
  if params["betrag"].to_i > 0
    @konto.add_new_ueberweisung(params["ziel"], -params["betrag"].to_i, "ÜBERWEISUNG")
    @ueberweisung = @konto.ueberweisungen.last
    json_response["message"] = "Überweisung erfoglreich"
    json_response["ueberweisung"] = @ueberweisung.as_json
    JSON.generate json_response
  else
    @err_msg = "Ihre eingabe war inkorrekt"
    JSON.generate error(@err_msg)
  end
end

# konto_pin_ändern-------------------------------

get "/konten/:id/pin_aendern" do
  @konto = Konto.get(params["id"])
  @konto_id = @konto.id
  @pin_alt = params["pin_alt"]
  @pin1 = params["pin_neu1"]
  @pin2 = params["pin_neu2"]
  if @pin_alt == @konto.pin
    if @pin1.size == 3 && @pin1 == @pin2
      @konto.aendere_pin(@pin1)
      @neue_pin = @pin1
      json_response["message"] = "Pin änderung erfoglreich"
      json_response["Pin"] = @neue_pin
      JSON.generate json_response
    else
      @err_msg = "Ihre eingabe war inkorrekt"
      JSON.generate error(@err_msg)
    end
  else
    @err_msg = "Ihre eingaben stimmen nicht überein oder sind nicht 3-stellig"
    JSON.generate error(@err_msg)
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

def redirect_if_not_logged_in(konto)
  if params["username"] && params["pin"] && konto.authenticated?(params["pin"]) && konto.konto_nr == params["username"]

  else
    redirect "/"
  end
end


def json_response
  @json_response ||= Hash.new
end

def error(text)
  json_response["error"] = text
end

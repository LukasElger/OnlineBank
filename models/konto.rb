class Konto

  def initialize(konto_nr, pin, betrag)
    @konto_nr = konto_nr
    @pin = pin
    @anfangs_saldo = betrag

    @ueberweisungen = load_bookings
  end

  def konto_nr
    @konto_nr
  end

  def aendere_pin(neue_pin)
    @pin = neue_pin
  end

  def pin
    @pin
  end

  def kontostand
    ergebnis = 0
    @ueberweisungen.each do |ueberweisung|
      ergebnis += ueberweisung.betrag
    end

    ergebnis + @anfangs_saldo.to_i
  end

  def ueberweisungen
    @ueberweisungen
  end

  def add_new_ueberweisung(quelle, ziel, betrag, grund)
    @ueberweisungen << Ueberweisung.new(quelle, ziel, betrag.to_i, grund)
  end

  def ausgehenede_ueberweisung(ziel, betrag, grund)
    add_new_ueberweisung(@konto_nr, ziel, betrag, grund)
  end

  def ueberweisung_to_csv
    file = File.open("/home/le/workspace/OnlineBank/Konten/#{@konto_nr}.csv", "w+")
    file.write(booking_csv)
    file.close
  end

  def authenticated?(password)
    password == @pin
  end

  def to_csv
    "#{@konto_nr},#{@pin},#{@anfangs_saldo}"
  end

  def booking_csv
    result = []
    @ueberweisungen.each do |ueberweisung|
      result << ueberweisung.to_csv
    end
    result.join("\n")
  end

  def load_bookings
    temp = []
    File.open("/home/le/workspace/OnlineBank/Konten/#{@konto_nr}.csv", "a+").each do |line|
      quelle, ziel, betrag, grund = line.chomp.split(",")
      temp << Ueberweisung.new(quelle, ziel, betrag.to_i, grund)
    end
    temp
  end
end

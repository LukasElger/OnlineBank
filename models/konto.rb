class Konto
  include DataMapper::Resource
  property :id,           Serial
  property :konto_nr,    String, required: true
  property :pin,          String, required: true

  has n, :ueberweisungen, "Ueberweisung", constraint: :destroy

  def aendere_pin(neue_pin)
    self.pin = neue_pin
    self.save
  end

  def kontostand
    ueberweisungen.sum(:betrag)
  end

  def add_new_ueberweisung(ziel, betrag, grund)
    Ueberweisung.create(konto: self, ziel: ziel, betrag: betrag.to_i, verwendungszweck: grund)
    self.save
  end

  def authenticated?(password)
    password == pin
  end

  def to_csv
    "#{konto_nr},#{pin}"
  end
end

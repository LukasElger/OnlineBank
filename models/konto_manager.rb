class KontoManager
  STORAGE = "/home/le/workspace/OnlineBank/Konten/konto_information.csv"

  def initialize(file_path=STORAGE)
    @path = file_path
    @konten = read_from_file
  end

  def read_from_file
    konten_temp = {}
    File.open(@path).each do |line|
      konto_nr, pin, betrag = line.chomp.split(",")
      konten_temp[konto_nr] = Konto.new(konto_nr, pin, betrag)
    end

    konten_temp
  end

  def store_to_file
    file = File.open(@path, "w")
    file.write(to_csv)
    file.close
  end

  def konten
    @konten
  end

  def add_new_konto(konto_nr, pin, betrag)
    konten[konto_nr] = Konto.new(konto_nr.to_s, pin.to_s, betrag)
  end

  def delete_konto(konto_nr)
    konten.delete(konto_nr)
    delete_file(konto_nr)
  end

  def delete_file(konto_nr)
    File.delete("/home/le/workspace/OnlineBank/Konten/#{konto_nr}.csv")
  end

  def to_csv
    result = []
    konten.each do |konto_nr, konto|
      result << konto.to_csv
    end

    result.join("\n")
  end
end

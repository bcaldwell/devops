# from mogest/unix-crypt

require 'securerandom'

class UnixCrypt
  def self.build(password, salt = nil, rounds = nil)
    salt ||= generate_salt
    if salt.length > max_salt_length
      raise UnixCrypt::SaltTooLongError, "Salts longer than #{max_salt_length} characters are not permitted"
    end

    construct_password(password, salt, rounds)
  end

  def self.hash(password, salt, rounds = nil)
    bit_specified_base64encode internal_hash(prepare_password(password), salt, rounds)
  end

  def self.generate_salt
    # Generates a random salt using the same character set as the base64 encoding
    # used by the hash encoder.
    SecureRandom.base64((default_salt_length * 6 / 8.0).ceil).tr("+", ".")[0...default_salt_length]
  end

  def self.construct_password(password, salt, rounds)
    "$#{identifier}$#{rounds_marker rounds}#{salt}$#{hash(password, salt, rounds)}"
  end

  def self.bit_specified_base64encode(input)
    b64 = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    input = input.bytes.to_a
    output = ""
    byte_indexes.each do |i3, i2, i1|
      b1 = i1 && input[i1] || 0
      b2 = i2 && input[i2] || 0
      b3 = i3 && input[i3] || 0
      output <<
        b64[b1 & 0b00111111] <<
        b64[((b1 & 0b11000000) >> 6) |
            ((b2 & 0b00001111) << 2)]  <<
        b64[((b2 & 0b11110000) >> 4) |
            ((b3 & 0b00000011) << 4)]  <<
        b64[(b3 & 0b11111100) >> 2]
    end

    remainder = 3 - (length % 3)
    remainder = 0 if remainder == 3
    output[0..-1 - remainder]
  end

  def self.prepare_password(password)
    # For Ruby 1.9+, convert the password to UTF-8, then treat that new string
    # as binary for the digest methods.
    if password.respond_to?(:encode)
      password = password.encode("UTF-8")
      password.force_encoding("ASCII-8BIT")
    end

    password
  end

  def self.default_salt_length
    16
  end

  def self.max_salt_length
    16
  end

  def self.default_rounds
    5000
  end

  def self.internal_hash(password, salt, rounds = nil)
    rounds = apply_rounds_bounds(rounds || default_rounds)
    salt = salt[0..15]

    b = digest.digest("#{password}#{salt}#{password}")

    a_string = password + salt + b * (password.length / length) + b[0...password.length % length]

    password_length = password.length
    while password_length > 0
      a_string += password_length & 1 != 0 ? b : password
      password_length >>= 1
    end

    input = digest.digest(a_string)

    dp = digest.digest(password * password.length)
    p = dp * (password.length / length) + dp[0...password.length % length]

    ds = digest.digest(salt * (16 + input.bytes.first))
    s = ds * (salt.length / length) + ds[0...salt.length % length]

    rounds.times do |index|
      c_string = (index & 1 != 0 ? p : input)
      c_string += s unless index % 3 == 0
      c_string += p unless index % 7 == 0
      c_string += (index & 1 != 0 ? input : p)
      input = digest.digest(c_string)
    end

    input
  end

  def self.apply_rounds_bounds(rounds)
    rounds = 1000        if rounds < 1000
    rounds = 999_999_999 if rounds > 999_999_999
    rounds
  end

  def self.rounds_marker(rounds)
    if rounds && rounds != default_rounds
      "rounds=#{apply_rounds_bounds(rounds)}$"
    end
  end

  def self.digest
    Digest::SHA512
  end

  def self.length
    64
  end

  def self.identifier
    6
  end

  def self.byte_indexes
    [[0, 21, 42], [22, 43, 1], [44, 2, 23], [3, 24, 45], [25, 46, 4], [47, 5, 26], [6, 27, 48], [28, 49, 7], [50, 8, 29], [9, 30, 51], [31, 52, 10],
     [53, 11, 32], [12, 33, 54], [34, 55, 13], [56, 14, 35], [15, 36, 57], [37, 58, 16], [59, 17, 38], [18, 39, 60], [40, 61, 19], [62, 20, 41], [nil, nil, 63]]
  end
end

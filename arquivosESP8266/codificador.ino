
#include <Wire.h>
#include <PN532_I2C.h>
#include <PN532.h>
#include <string.h>

// Modulo NFC
PN532_I2C pn532_i2c(Wire);
PN532 nfc(pn532_i2c);

// Cadastro dos cartoes
struct Cartao {
  uint8_t uid[4];
  char numero;
};

const Cartao cartoes[] = {
  {{0xE3, 0x7F, 0x10, 0x29}, '1'},
  {{0x9C, 0x71, 0x75, 0x06}, '2'},
  {{0x6F, 0xBC, 0xBF, 0x98}, '3'},
  {{0xF1, 0x72, 0x21, 0x00}, '4'},
  {{0x73, 0xC4, 0x3E, 0x14}, '5'},
  {{0x83, 0x85, 0xB7, 0x14}, '0'}

  // Novos cartoes: coloque virgula na linha anterior
  // ,{{0xAA, 0xBB, 0xCC, 0xDD}, '1'}
};

const int totalCartoes = sizeof(cartoes) / sizeof(cartoes[0]);

void setup() {
  Serial.begin(115200);

  Wire.begin(4, 5);
  Wire.setClock(100000);

  delay(1000);
  nfc.begin();

  if (!nfc.getFirmwareVersion()) {
    Serial.println("ERRO: PN532 nao encontrado!");
    return;
  }

  nfc.SAMConfig();

  // UART1: TX no D4, 115200 baud, 7E1
  Serial1.begin(115200, SERIAL_7E1);

  Serial.println("Sistema pronto!");
}

void loop() {
  uint8_t uid[7];
  uint8_t tamanho = 0;

  if (!nfc.readPassiveTargetID(
        PN532_MIFARE_ISO14443A, uid, &tamanho)) {
    return;
  }

  if (tamanho != 4) return;

  for (int i = 0; i < totalCartoes; i++) {
    if (memcmp(uid, cartoes[i].uid, 4) == 0) {

      char numero = cartoes[i].numero;

      Serial.print("Cartao: ");
      Serial.println(numero);

      Serial1.write(numero);

      delay(1000);
      return;
    }
  }

  Serial.println("Cartao desconhecido!");
  delay(1000);
}

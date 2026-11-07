
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

// Para implementação da máquina de estados

enum EstadoLeitor {
  AGUARDANDO_CARTAO,
  AGUARDANDO_RETIRADA
};

EstadoLeitor estado = AGUARDANDO_CARTAO;

const int LIMITE_AUSENCIAS = 3;
int ausenciasConsecutivas = 0;


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

  nfc.setPassiveActivationRetries(0x05);

  // UART1: TX no D4, 115200 baud, 7E1
  Serial1.begin(115200, SERIAL_7E1);

  Serial.println("Sistema pronto!");
}

void loop() {
  uint8_t uid[7];
  uint8_t tamanho = 0;

  bool detectado = nfc.readPassiveTargetID(
    PN532_MIFARE_ISO14443A,
    uid,
    &tamanho,
    200
  );

  // Nenhum cartao detectado
  if (!detectado) {
    if (estado == AGUARDANDO_RETIRADA) {
      ausenciasConsecutivas++;

      if (ausenciasConsecutivas >= LIMITE_AUSENCIAS) {
        estado = AGUARDANDO_CARTAO;
        ausenciasConsecutivas = 0;

        Serial.println("Cartao retirado!");
      }
    }

    return;
  }

  // Cartao presente: zera as ausencias
  ausenciasConsecutivas = 0;

  // Ja processamos um cartao.
  // Nao enviar novamente enquanto estiver presente.
  if (estado == AGUARDANDO_RETIRADA) {
    return;
  }

  // Novo cartao detectado
  estado = AGUARDANDO_RETIRADA;

  if (tamanho != 4) return;

  for (int i = 0; i < totalCartoes; i++) {
    if (memcmp(uid, cartoes[i].uid, 4) == 0) {

      char numero = cartoes[i].numero;

      Serial.print("Cartao: ");
      Serial.println(numero);

      Serial1.write(numero);

      return;
    }
  }

  Serial.println("Cartao desconhecido!");
}

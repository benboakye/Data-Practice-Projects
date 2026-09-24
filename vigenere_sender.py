def vigenere_encrypt(plaintext, key):
    ciphertext = ""
    key_index = 0

    key = key.upper()

    for char in plaintext:

        if char.isalpha():
            # Convert plaintext letter to number 0-25
            p = ord(char.upper()) - ord('A')

            # Select the corresponding key letter
            key_char = key[key_index % len(key)]

            # Convert key letter to number 0-25
            k = ord(key_char) - ord('A')

            # Vigenere encryption formula
            c = (p + k) % 26

            # Convert encrypted value back to a letter
            ciphertext += chr(c + ord('A'))

            # Move to the next key character
            key_index += 1

        else:
            # Preserve spaces and other non-alphabetic characters
            ciphertext += char

    return ciphertext


def main():
    message = input(
        'Enter the message "TO BE OR NOT TO BE THAT IS THE QUESTION": '
    )

    key = input(
        'Enter the Vigenere key "RELATIONS": '
    )

    encrypted_message = vigenere_encrypt(message, key)

    print("\n--- Vigenere Encryption ---")
    print("Original Message :", message)
    print("Encryption Key   :", key)
    print("Encrypted Message:", encrypted_message)


if __name__ == "__main__":
    main()
from getpass import getpass

from sqlalchemy.exc import SQLAlchemyError

from app.db.session import SessionLocal
from app.services.user_bootstrap import (
    BootstrapError,
    create_initial_chief,
)


def _required_input(label: str) -> str:
    while True:
        value = input(label).strip()
        if value:
            return value
        print("Bu alan boş bırakılamaz.")


def _read_password() -> str:
    while True:
        password = getpass("Geçici parola: ")
        confirmation = getpass("Geçici parola (tekrar): ")

        if password != confirmation:
            print("Parolalar eşleşmiyor. Yeniden deneyin.")
            continue

        return password


def main() -> int:
    print("TCK YÖSİ - İlk şef hesabı oluşturma")
    print("Parola ekranda görünmez ve komut geçmişine yazılmaz.\n")

    full_name = _required_input("Ad soyad: ")
    username = _required_input("Kullanıcı adı: ")
    email_input = input("E-posta (isteğe bağlı): ").strip()
    password = _read_password()

    try:
        with SessionLocal() as session:
            user = create_initial_chief(
                session,
                full_name=full_name,
                username=username,
                email=email_input or None,
                password=password,
            )
    except BootstrapError as exc:
        print(f"\nHesap oluşturulamadı: {exc}")
        return 1
    except SQLAlchemyError:
        print("\nHesap oluşturulamadı: Veritabanı işlemi başarısız oldu.")
        return 1

    print(f"\nİlk şef hesabı oluşturuldu: {user.username}")
    print("İlk girişte parolanın değiştirilmesi zorunlu olacak.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

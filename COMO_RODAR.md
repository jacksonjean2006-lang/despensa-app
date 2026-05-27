# Como rodar o projeto pela primeira vez

## 1. Instalar dependências do Flutter

Abra o terminal na pasta do projeto:

```
cd "C:\PROJETOS\Lista de Compras\app"
flutter create despensa --org com.despensa --platforms android
```

## 2. Copiar os arquivos do código

Após o `flutter create`, copie os arquivos que já estão na pasta `app\` para dentro de `app\despensa\`:

- `pubspec.yaml` → substitui o gerado
- Toda a pasta `lib\` → substitui a pasta `lib\` gerada

Ou no terminal:
```
xcopy /E /Y "C:\PROJETOS\Lista de Compras\app\lib" "C:\PROJETOS\Lista de Compras\app\despensa\lib\"
copy /Y "C:\PROJETOS\Lista de Compras\app\pubspec.yaml" "C:\PROJETOS\Lista de Compras\app\despensa\pubspec.yaml"
```

## 3. Adicionar permissão de câmera no Android

Edite o arquivo:
`despensa\android\app\src\main\AndroidManifest.xml`

Adicione dentro de `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

## 4. Instalar dependências e rodar

```
cd despensa
flutter pub get
flutter run
```

## 5. Gerar APK para instalar no celular

```
flutter build apk --release
```

O APK ficará em:
`despensa\build\app\outputs\flutter-apk\app-release.apk`

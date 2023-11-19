#include <QMainWindow>
#include <QApplication>
#include <zip.h>
#include <iostream>

int main(int argc,char**argv) {
    QApplication app{argc,argv};

    QMainWindow w;
    w.show();

    std::cout<<"Version of libzip: "<<zip_libzip_version()<<std::endl;

    return app.exec();
}
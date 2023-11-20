#include <QMainWindow>
#include <QApplication>
#include <iostream>
#include "lib.h"
#include <zip.h>

int main(int argc,char**argv) {
    QApplication app{argc,argv};

    QMainWindow w;
    w.show();

    std::cout<<"Version of libzip: "<<SH_libzip_version()<<std::endl;
    std::cout<<"Version of libzip: "<<zip_libzip_version()<<std::endl;

    return app.exec();
}
@echo Create OS Product (create_os_product.pl)
perl create_os_product.pl
@echo Extract OS Product Data to template (create_product.pl -o)
perl create_product.pl -o
@echo Extract OS Product Instances (create_os_product_instance.pl)
perl create_os_product_instance.pl
:END

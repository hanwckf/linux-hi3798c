// SPDX-License-Identifier: GPL-2.0

#include <linux/module.h>
#include <linux/of_address.h>
#include <linux/platform_device.h>
#include <linux/thermal.h>
#include <linux/delay.h>

#define PERI_PMC10_OFFSET 	0x28
#define PERI_PMC12_OFFSET	0x30

struct hisi_sensor {
	void __iomem *mmio_base;
	struct thermal_zone_device *tzd;
};

static struct hisi_sensor hisi_temp_sensor;

static int get_sensor_value(u32 *val, void __iomem *mmio_base)
{
	u32 u32RegVal;
	u8 i, j;
	u32 u32TsensorAverage = 0;
	u32 u32TempValue;

	writel(0x6005, mmio_base + PERI_PMC10_OFFSET);
	mdelay(16);
	for (j = 0; j < 4; j++)
	{
		u32RegVal = readl((mmio_base + PERI_PMC12_OFFSET) + 0x4 * j);
		for (i = 0; i < 2; i++)
		{
			u32TsensorAverage += ((u32RegVal >> (16 * i)) & 0x3ff);
		}
	}
	writel(0x0, mmio_base + PERI_PMC10_OFFSET);

	u32TsensorAverage = (u32TsensorAverage / 8);
	u32TempValue = ((u32TsensorAverage - 125) * 165 / 806) - 40;

	*val = u32TempValue * 1000; /* mC */

	return 0;
}

static int get_temp_value(void *data, int *temp)
{
	struct hisi_sensor *sensor = (struct hisi_sensor *)data;
	u32 val;
	int ret;

	ret = get_sensor_value(&val, sensor->mmio_base);
	
	if (ret)
		return ret;

	*temp = (int)val;

	return 0;
}

static struct thermal_zone_of_device_ops thermal_ops = {
	.get_temp = get_temp_value,
};

static int hisi_thermal_probe(struct platform_device *pdev)
{
	struct hisi_sensor *sensor_data = &hisi_temp_sensor;
	struct resource *resource;

	platform_set_drvdata(pdev, sensor_data);

	resource = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	sensor_data->mmio_base = devm_ioremap_resource(&pdev->dev, resource);
	if (IS_ERR(sensor_data->mmio_base)) {
		dev_err(&pdev->dev, "failed to ioremap memory (%ld)\n",
			PTR_ERR(sensor_data->mmio_base));
		return PTR_ERR(sensor_data->mmio_base);
	}

	sensor_data->tzd = devm_thermal_zone_of_sensor_register(&pdev->dev,
							    0,
							    sensor_data,
							    &thermal_ops);

	if (IS_ERR(sensor_data->tzd)) {
		dev_err(&pdev->dev,
			"failed to register sensor (%ld)\n",
			PTR_ERR(sensor_data->tzd));
		return PTR_ERR(sensor_data->tzd);
	}

	thermal_zone_device_update(sensor_data->tzd, THERMAL_EVENT_UNSPECIFIED);

	dev_info(&pdev->dev, "probe success\n");

	return 0;
}

static int hisi_thermal_exit(struct platform_device *pdev)
{
	struct hisi_sensor *sensor = platform_get_drvdata(pdev);

	devm_thermal_zone_of_sensor_unregister(&pdev->dev, sensor->tzd);
	platform_set_drvdata(pdev, NULL);

	return 0;
}

static const struct of_device_id hi3798c_thermal_id_table[] = {
	{
		.compatible = "hisilicon,hi3798cv200-thermal",
	},
	{}
};

MODULE_DEVICE_TABLE(of, hi3798c_thermal_id_table);

static struct platform_driver hi3798c_thermal_driver = {
	.probe = hisi_thermal_probe,
	.remove = hisi_thermal_exit,
	.driver = {
		.name = "hi3798c_thermal",
		.of_match_table = hi3798c_thermal_id_table,
	},
};

module_platform_driver(hi3798c_thermal_driver);

MODULE_DESCRIPTION("hi3798c thermal driver");
MODULE_LICENSE("GPL v2");
